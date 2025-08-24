%define HTTP_SYMBOLS
%include "http.inc"
%include "net.inc"
%include "mem.inc"
%include "helpers.inc"
%include "linkedlist.inc"
%include "http_fields.inc"
%include "io.inc"
%include "log.inc"

section .bss
    global http_server

    http_server equ server
    handler: resq 1

%define BAD_REQUEST_BODY "400 Bad Request"
%strlen BAD_REQUEST_BODY_LEN BAD_REQUEST_BODY

section .data
    recived_msg: db "recived request: ", 0
    ver_str: db "HTTP/1.1", 0
        .len equ $- ver_str-1

    bad_request_str: db "Bad Request", 0
    bad_request_body: db BAD_REQUEST_BODY
        .len equ BAD_REQUEST_BODY_LEN
        .len_str db %str(BAD_REQUEST_BODY_LEN), 0

    LL_STATIC bad_request_headers, HttpHeader.size, bad_request_content_lenght, bad_request_connection
    LL_STATIC_NODE bad_request_content_lenght, , bad_request_connection, 0
    istruc HttpHeader
        at HttpHeader.field, dq content_lenght
        at HttpHeader.value, dq bad_request_body.len_str
    iend
    LL_STATIC_NODE bad_request_connection, , 0, bad_request_content_lenght
istruc HttpHeader
        at HttpHeader.field, dq connection

section .text
    global http_init
    global http_main_loop
    global http_send_responce
    global send_with_default_headers
    global send_bad_request
    global http_header_get_val

http_init: ; (u16 port, u32 address, handler(fd, HttpRequest) -> bool) -> HttpServer*
    push rbp ; align the stack

    mov [handler], rdx

    lea rdx, http_handler
    call server_init

    pop rbp

    ret

http_main_loop:
    push rbp
    mov rbp, rsp

    call server_main_loop

    mov rsp, rbp
    pop rbp

    ret
    
; this should only be used by http_handler
http_handler_free_request: ; (HttpRequest*)
    push rbp
    mov rbp, rsp

    sub rsp, 24
    mov [rbp-8], rdi ; [rbp-8]=request
    ; [rbp-16]=header_iter
    ; [rbp-24]=current_header

    mov rdi, [rdi+HttpRequest.method]
    test rdi, rdi
    jz .no_method

    call free

.no_method:
    mov rdi, [rbp-8]
    mov rdi, [rdi+HttpRequest.path]
    test rdi, rdi
    jz .no_path

    call free

.no_path:
    mov rdi, [rbp-8]
    mov rdi, [rdi+HttpRequest.ver]
    test rdi, rdi
    jz .no_ver

    call free

.no_ver:
    mov rdi, [rbp-8]
    mov rdi, [rdi+HttpRequest.headers]
    test rdi, rdi
    jz .no_headers

    call ll_iter
    mov [rbp-16], rax

.header_loop:
    mov rdi, [rbp-16]
    call ll_iter_next
    mov [rbp-16], rax
    mov [rbp-24], rdx

    test rdx, rdx
    jz .header_loop_end

    mov rdi, [rdx+HttpHeader.field]
    test rdi, rdi
    jz .no_header_field

    call free

.no_header_field:
    mov rdx, [rbp-24]
    mov rdi, [rdx+HttpHeader.value]
    test rdi, rdi
    jz .no_header_value

    call free

.no_header_value:
    jmp .header_loop
    
.header_loop_end:
    mov rdi, [rbp-8]
    mov rdi, [rdi+HttpRequest.headers]
    call ll_clear

.no_headers:
    mov rdi, [rbp-8]
    mov rdi, [rdi+HttpRequest.body]
    test rdi, rdi
    jz .no_body

    mov rdi, [rdi+HttpBody.ptr]
    call free

.no_body:
    mov rsp, rbp
    pop rbp

    ret

http_handler: ; (u32 fd)
    push rbp
    mov rbp, rsp

    sub rsp, 128
    ; [rbp-24]=reader
    ; [rbp-64]=request
    ; [rbp-96]=body
    ; [rbp-120]=headers
    ; [rbp-128]=current_header

    mov esi, edi
    lea rdi, [rbp-24]
    call bfr_init

; main loop
.loop:
    ; initialise every field of the request to zero
    mov qword [rbp-64+HttpRequest.method], 0
    mov qword [rbp-64+HttpRequest.headers], 0
    mov qword [rbp-64+HttpRequest.ver], 0
    mov qword [rbp-64+HttpRequest.body], 0

    lea rdi, [rbp-24]
    call bfr_fill_buf

    test rax, rax
    js .error
    jz .exit ; connection closed

    ; parse status line
    
    ; read the method
    lea rdi, [rbp-24]
    mov sil, ' '
    call bfr_read_until

    test rax, rax
    js .error
    jz .bad_request

    ; replace the last char with zero
    dec rdx
    mov byte [rdx+rax], 0

    mov [rbp-64+HttpRequest.method], rax ; save the method

    ; read the path
    lea rdi, [rbp-24]
    mov sil, ' '
    call bfr_read_until

    test rax, rax
    js .error
    jz .bad_request

    ; replace the last char with zero
    dec rdx
    mov byte [rdx+rax], 0

    mov [rbp-64+HttpRequest.path], rax

    ; read the ver
    lea rdi, [rbp-24]
    mov sil, `\r`
    call bfr_read_until

    test rax, rax
    js .error
    jz .bad_request

    ; replace the last char with zero
    dec rdx
    mov byte [rdx+rax], 0

    mov [rbp-64+HttpRequest.ver], rax

    lea rdi, [rbp-24]
    mov rsi, 1
    call bfr_skip
    
    lea rdi, [rbp-120]
    mov rsi, HttpHeader.size
    call ll_init
   
    lea rax, [rbp-120]
    mov [rbp-64+HttpRequest.headers], rax
.header_loop:
    lea rdi, [rbp-24]
    lea rsi, [rbp-128]; use current header as buffer for bfr peak
    mov rdx, 1
    call bfr_peek
    
    test rax, rax
    js .error
    jz .bad_request

    mov dil, [rbp-128]
    cmp dil, `\r`
    je .header_loop_end

    lea rdi, [rbp-120]
    xor rsi, rsi
    call ll_push_back
    mov [rbp-128], rax

    ; initialise the header's field to null
    mov qword [rax+HttpHeader.field], 0
    mov qword [rax+HttpHeader.value], 0
    
    lea rdi, [rbp-24]
    mov sil, `:`
    call bfr_read_until
    
    test rax, rax
    js .error
    jz .bad_request

    dec rdx
    mov byte [rdx+rax], 0

    mov rsi, [rbp-128]
    mov [rsi+HttpHeader.field], rax

    lea rdi, [rbp-24]
    mov sil, `\r`
    call bfr_read_until
    
    test rax, rax
    js .error
    jz .bad_request

    dec rdx
    mov byte [rdx+rax], 0

    mov rsi, [rbp-128]
    mov [rsi+HttpHeader.value], rax

    lea rdi, [rbp-24]
    mov rsi, 1
    call bfr_skip

    jmp .header_loop
.header_loop_end:
    lea rdi, [rbp-24]
    mov rsi, 2
    call bfr_skip
    
    mov rdi, [rbp-64+HttpRequest.headers]
    lea rsi, [content_lenght]
    call http_header_get_val

    test rax, rax
    jz .no_body

    mov rdi, rax
    call stoi

    mov [rbp-96+HttpBody.len], rax

    lea rdi, [rbp-96]
    mov [rbp-64+HttpRequest.body], rdi

    lea rdi, [rax+1]
    call malloc

    mov [rbp-96+HttpBody.ptr], rax

    ; TODO: support bodies larger than BFR_MAX_BUFSIZE
    lea rdi, [rbp-24]
    mov rsi, rax
    mov rdx, [rbp-96+HttpBody.len]
    call bfr_read_all

    test rax, rax
    js .error

    ; put a zero after the body
    mov rdi, [rbp-96+HttpBody.ptr]
    mov byte [rdi+rdx], 0

    mov [rbp-96+HttpBody.len], rdx
    
    jmp .body_parse_end
.no_body:
    mov qword [rbp-64+HttpRequest.body], 0

.body_parse_end:
    ; log request
    mov rdi, recived_msg
    call print

    info s, recived_msg, c, ' ', sp, [rbp-64+HttpRequest.method], c, ' ', sp, [rbp-64+HttpRequest.path], c, `\n`

    ; call the handler
    mov edi, [rbp-24+BufferedFileReader.fd]
    lea rsi, [rbp-64]
    call [handler]

    test rax, rax
    jz .exit

    ; free the request
    lea rdi, [rbp-64]
    call http_handler_free_request
    
    jmp .loop
.error:
    cmp rax, EFBIG
    je .bad_request

    ; store the error in [rbp-128]
    mov [rbp-128], rax
    
    error is, "error while reading http request : ", i, [rbp-128], c, `\n`

    jmp .exit
.bad_request:
    mov edi, [rbp-8]
    call send_bad_request
.exit:
    ; free the request
    lea rdi, [rbp-64]
    call http_handler_free_request

    ; free the buffer
    lea rdi, [rbp-24]
    call bfr_free

    mov rsp, rbp
    pop rbp

    ret

; TODO: write directly instead of computing size then mallocing a buffer
http_send_responce: ; (u32 fd, HttpResponce*)
    push rbp
    mov rbp, rsp

    sub rsp, 80 ; make room for vars
    ; [rbp-16] atoi buffer
    mov [rbp-20], rdi; [rbp-20]=fd
    mov [rbp-32], rsi; [rbp-32]=responce
    ; [rbp-40]=len
    ; [rbp-48]=i
    ; [rbp-56]=buf
    ; [rbp-64]=buf_ptr (offseted)
    ; [rbp-72]=current_header

    ; convert code to string
    lea rdi, [rbp-16]
    mov edx, [rsi+HttpResponce.status_code]
    mov rsi, 16
    mov rcx, 0
    call itos

    ; get the lenght of the status code str
    mov rdi, rax
    call strlen

    ; compute the lenght of the responce string
    mov qword [rbp-40], ver_str.len
    add [rbp-40], rax

    ; compute the lenght of the status string
    mov rdi, [rbp-32]
    mov rdi, [rdi+HttpResponce.status_str]
    call strlen

    add [rbp-40], rax
    add qword [rbp-40], 4 ; add the spaces and the crlf

    mov rdi, [rbp-32]
    mov rdi, [rdi+HttpResponce.headers]
    test rdi, rdi
    jz .no_headers_len

    mov qword [rbp-48], rdi
    
    call ll_is_empty
    test rax, rax
    jz .no_headers_len

    mov qword [rbp-48], rdi
    call ll_iter
    mov qword [rbp-48], rax

.header_len_loop:
    mov rdi, [rbp-48]
    call ll_iter_next
    mov [rbp-48], rax
    mov [rbp-72], rdx
    test rdx, rdx
    jz .no_headers_len

    mov rdi, [rdx+HttpHeader.field]
    call strlen
    add [rbp-40], rax

    mov rdx, [rbp-72]
    mov rdi, [rdx+HttpHeader.value]
    call strlen
    add [rbp-40], rax

    add qword [rbp-40], 4 ; add the lenght for the crlf and the space and colon
    jmp .header_len_loop

.no_headers_len:
    mov rdi, [rbp-32]
    mov rdi, [rdi+HttpResponce.body]
    test rdi, rdi
    jz .no_body_len

    mov rax, [rdi+HttpBody.len]
    add [rbp-40], rax

    add qword [rbp-40], 2 ; add the lenght of the crlf before the body
.no_body_len:
    ; alloc a buffer to store the request data
    mov rdi, [rbp-40]
    call malloc
    mov [rbp-56], rax
    mov [rbp-64], rax

    ; copy the version string
    mov rdi, rax
    lea rsi, [ver_str]
    mov rdx, ver_str.len
    call memcpy
    add qword [rbp-64], ver_str.len

    mov rdi, [rbp-64]
    mov byte [rdi], ' '
    inc qword [rbp-64]

    lea rdi, [rbp-16]
    call strlen

    mov rdi, [rbp-64]
    lea rsi, [rbp-16]
    mov rdx, rax
    add qword [rbp-64], rax
    call memcpy

    mov rdi, [rbp-64]
    mov byte [rdi], ' '
    inc qword [rbp-64]

    mov rdi, [rbp-32]
    mov rdi, [rdi+HttpResponce.status_str]
    call strlen

    mov rdi, [rbp-64]
    mov rsi, [rbp-32]
    mov rsi, [rsi+HttpResponce.status_str]
    mov rdx, rax
    add qword [rbp-64], rax
    call memcpy

    mov rdi, [rbp-64]
    mov word [rdi], `\r\n`
    add qword [rbp-64], 2
    
    mov rdi, [rbp-32]
    mov rdi, [rdi+HttpResponce.headers]
    test rdi, rdi
    jz .no_headers_str

    mov qword [rbp-48], rdi
    
    call ll_is_empty
    test rax, rax
    jz .no_headers_str

    mov qword [rbp-48], rdi
    call ll_iter
    mov qword [rbp-48], rax

.header_str_loop:
    mov rdi, [rbp-48]
    call ll_iter_next
    mov [rbp-48], rax
    mov [rbp-72], rdx
    test rdx, rdx
    jz .no_headers_str

    mov rdi, [rdx+HttpHeader.field]
    call strlen

    mov rdi, [rbp-64]
    mov rsi, [rbp-72]
    mov rsi, [rsi+HttpHeader.field]
    mov rdx, rax
    add qword [rbp-64], rax
    call memcpy

    mov rdi, [rbp-64]
    mov word [rdi], `: `
    add qword [rbp-64], 2


    mov rdx, [rbp-72]
    mov rdi, [rdx+HttpHeader.value]
    call strlen
    
    mov rdi, [rbp-64]
    mov rsi, [rbp-72]
    mov rsi, [rsi+HttpHeader.value]
    mov rdx, rax
    add qword [rbp-64], rax
    call memcpy

    mov rdi, [rbp-64]
    mov word [rdi], `\r\n`
    add qword [rbp-64], 2


    add qword [rbp-40], 4 ; add the lenght for the crlf and the space and colon
    jmp .header_str_loop
.no_headers_str:
    mov rdx, [rbp-32]
    mov rdx, [rdx+HttpResponce.body]
    test rdx, rdx
    jz .no_body_str

    mov rax, [rdx+HttpBody.len]

    mov rdi, [rbp-64]
    mov word [rdi], `\r\n`
    add qword [rbp-64], 2

    mov rdi, [rbp-64]
    mov rsi, [rdx+HttpBody.ptr]
    mov rdx, rax
    add qword [rbp-64], rax
    call memcpy

.no_body_str:
    ; write the responce to the socket
    mov rax, 1 ; sys_write
    mov rdi, [rbp-20] ; fd
    mov rsi, [rbp-56] ; buf
    mov rdx, [rbp-40] ; len
    syscall

    mov rdi, [rbp-56]
    call free

    mov rsp, rbp
    pop rbp

    ret

; send with the content_lenght and connetion headers
send_with_default_headers: ; (u32 fd, HttpResponce*, bool keep_alive)
    push rbp
    mov rbp, rsp

    sub rsp, 128
    ; [rbp-24]=header_list
    mov [rbp-32], rsi; [rbp-32]=responce
    ; [rbp-64]=content_lenght_header_node [rbp-48]=node_data
    ; [rbp-96]=connection_header_node [rbp-80]=node_data
    mov [rbp-100], edi; [rbp-100]=fd
    mov [rbp-104], edx; [rbp-104]=keep_alive
    ; [rbp-128]=content_lenght_buffer

    ; initalize the header list
    mov qword [rbp-24+LinkedList.item_size], HttpHeader.size
    lea rax, [rbp-64]
    mov [rbp-24+LinkedList.front_node], rax
    lea rax, [rbp-96]
    mov [rbp-24+LinkedList.back_node], rax
    ; initalise the content_lenght_header_node
    mov [rbp-64+LLNodeHeader.next], rax 
    mov qword [rbp-64+LLNodeHeader.prev], 0
    mov qword [rbp-48+HttpHeader.field], content_lenght
    lea rdi, [rbp-128]
    mov rsi, 24
    mov rdx, [rbp-32]
    mov rdx, [rdx+HttpResponce.body]
    mov edx, [rdx+HttpBody.len]
    mov ecx, 0
    call itos
    mov qword [rbp-48+HttpHeader.value], rax
    ; initalize the connection_header_node
    lea rax, [rbp-64]
    mov [rbp-96+LLNodeHeader.prev], rax 
    mov qword [rbp-96+LLNodeHeader.next], 0
    mov qword [rbp-80+HttpHeader.field], connection
    mov rax, connection_keep_alive
    mov edi, [rbp-104]
    mov rdx, connection_close
    test edi, edi
    cmovz rax, rdx
    mov qword [rbp-80+HttpHeader.value], rax
    ; make the responce headers point  to the linked list
    lea rax, [rbp-24]
    mov rsi, [rbp-32]
    mov [rsi+HttpResponce.headers], rax
    ; send the responce
    mov edi, [rbp-100]
    call http_send_responce
    

    mov rsp, rbp
    pop rbp

    ret

send_bad_request: ; (u32 fd)
    push rbp
    mov rbp, rsp

    sub rsp, 48
    ; [rbp-32]=responce
    ; [rbp-48]=body

    mov dword [rbp-32+HttpResponce.status_code], 400
    mov qword [rbp-32+HttpResponce.status_str], bad_request_str
    mov qword [rbp-32+HttpResponce.headers], bad_request_headers
    lea rax, [rbp-48]
    mov qword [rbp-32+HttpResponce.body], rax
    mov qword [rax+HttpBody.ptr], bad_request_body
    mov qword [rax+HttpBody.len], bad_request_body.len

    lea rsi, [rbp-32]
    call http_send_responce

    mov rsp, rbp
    pop rbp

    ret

http_header_get_val: ; (LinkedList*, char*) -> char*
    push rbp
    mov rbp, rsp

    mov rdx, rsi
    lea rsi, [.comparator]
    call ll_find

    test rax, rax
    jz .not_found

    mov rax, [rax+HttpHeader.value]

.exit:
    mov rsp, rbp
    pop rbp

    ret
.not_found:
    xor rax, rax
    jmp .exit

.comparator: ; (char*, HttpHeader*) -> bool
    push rbp
    mov rbp, rsp

    mov rsi, [rsi+HttpHeader.field]
    call strcmp

    test eax, eax
    setz al

    movzx eax, al

    mov rsp, rbp
    pop rbp

    ret
