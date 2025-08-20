%define HTTP_SYMBOLS
%include "http.inc"
%include "net.inc"
%include "mem.inc"
%include "helpers.inc"
%include "linkedlist.inc"
%include "http_fields.inc"

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
    
http_handler: ; (u32 fd)
    push rbp
    mov rbp, rsp

    sub rsp, 96
    mov [rbp-8], rdi ; [rbp-8]=fd
    ; [rbp-16]=buf
    ; [rbp-56]=request
    ; [rbp-64]=offset
    ; [rbp-72]=buf_len
    ; [rbp-96]=body

    mov rdi, 1024
    call malloc

    mov [rbp-16], rax

; main loop
.loop:
    ; read a request
    mov rax, 0 ; sys_read
    mov edi, [rbp-8] ; fd
    mov rsi, [rbp-16] ; buf
    mov rdx, 1023 ; len-1 to store a zero at the end
    syscall

    test rax, rax
    js .error

    mov [rbp-72], rax ; save buf_len
    ; null terminate the buf
    mov rdi, [rbp-16]
    mov byte [rdi+rax], 0

    ; parse status line
    
    ; read the method
    mov rdi, [rbp-16]
    mov rsi, rax
    mov dl, ' '
    call find_char

    ; put a zero where there was a space
    mov rdi, [rbp-16]
    mov byte [rdi+rax], 0

    mov [rbp-56+HttpRequest.method], rdi ; save the method
    inc rax
    mov [rbp-64], rax, ; save the offset

    ; read the path
    mov rdi, [rbp-16]
    add rdi, [rbp-64]
    mov rsi, [rbp-72]
    sub rsi, rax ; substract the offset from the size
    mov dl, ' '
    call find_char

    ; put a zero where there was a space
    mov rdi, [rbp-16]
    add rdi, [rbp-64]
    mov byte [rdi+rax], 0

    mov [rbp-56+HttpRequest.path], rdi
    add [rbp-64], rax, ; save the offset

    ; read the ver
    mov rdi, [rbp-16]
    add rdi, [rbp-64]
    mov rsi, [rbp-72]
    sub rsi, rax ; substract the offset from the size
    mov dl, '\r'
    call find_char

    ; put a zero where there was a new line
    mov rdi, [rbp-16]
    add rdi, [rbp-64]
    mov byte [rdi+rax], 0

    mov [rbp-56+HttpRequest.ver], rdi
    add [rbp-64], rax, ; save the offset

    inc qword [rbp-64] ; increase the offset to skip the new line

.header_loop:
    mov rdi, [rbp-16]
    add rdi, [rbp-64]
    cmp byte [rdi], `\r`
    je .header_loop_end
    
    ; TODO : parse the headers

    mov rdi, [rbp-16]
    add rdi, [rbp-64]
    mov rsi, [rbp-72]
    sub rsi, [rbp-64] ; substract the offset from the size
    mov dl, `\r`
    call find_char

    add [rbp-64], rax
    add qword [rbp-64], 2

    jmp .header_loop
    
.header_loop_end:
    add qword [rbp-64], 2
    mov rdi, [rbp-16]
    add rdi, [rbp-64]
    
    mov al, [rdi]
    test al, al 
    jz .no_body

    lea rax, [rbp-96]
    mov [rbp-56+HttpRequest.body], rax
    mov [rax+HttpBody.ptr], rdi
    mov rax, [rbp-72]
    sub rax, [rbp-64] 
    mov [rbp-96+HttpBody.len], rax
    
    jmp .body_parse_end
.no_body:
    mov qword [rbp-56+HttpRequest.body], 0

.body_parse_end:
    ; log request
    mov rdi, recived_msg
    call print

    mov rdi, [rbp-56+HttpRequest.method]
    call print

    mov dil, ' '
    call putchar

    mov rdi, [rbp-56+HttpRequest.path]
    call print

    mov dil, 10
    call putchar

    ; call the handler
    mov edi, [rbp-8]
    lea rsi, [rbp-56]
    call [handler]

    test rax, rax
    jnz .loop
    jmp .exit

.error:
    mov rdi, rax
    call printi

.exit:
    ; free the buffer
    mov rdi, [rbp-16]
    call free

    mov rsp, rbp
    pop rbp

    ret

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

    sub rbp, 48
    ; [rbp-32]=responce
    ; [rbp-48]=body

    mov dword [rbp-32+HttpResponce.status_code], 400
    mov qword [rbp-32+HttpResponce.status_str], bad_request
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
