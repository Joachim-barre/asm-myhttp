%define HTTP_SYMBOLS
%include "http.inc"
%include "net.inc"
%include "mem.inc"
%include "helpers.inc"

section .bss
    global http_server

    http_server equ server
    handler: resq 1

section .data
    recived_msg: db "recived request: ", 0
    ver_str: db "HTTP/1.1", 0
        .len equ $- ver_str-1

section .text
    global http_init
    global http_main_loop
    global http_send_responce

http_init: ; (u16 port, u32 address, handler(fd, HttpRequest)) -> HttpServer*
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

    sub rsp, 80
    mov [rbp-8], rdi ; [rbp-8]=fd
    ; [rbp-16]=buf
    ; [rbp-56]=request
    ; [rbp-64]=offset
    ; [rbp-72]=buf_len

    mov rdi, 1024
    call malloc

    mov [rbp-16], rax

; main loop
.loop:
    ; read a request
    mov rax, 0 ; sys_read
    mov edi, [rbp-8] ; fd
    mov rsi, [rbp-16] ; buf
    mov rdx, 1024 ; len
    syscall

    test rax, rax
    js .error

    mov [rbp-72], rax ; save buf_len

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
    mov dl, ' '
    call find_char

    ; put a zero where there was a new line
    mov rdi, [rbp-16]
    add rdi, [rbp-64]
    mov byte [rdi+rax], 0

    mov [rbp-56+HttpRequest.ver], rdi
    add [rbp-64], rax, ; save the offset

    ; TODO: parse the rest

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

    sub rsp, 64 ; make room for vars
    ; [rbp-16] atoi buffer
    mov [rbp-20], rdi; [rbp-20]=fd
    mov [rbp-32], rsi; [rbp-32]=responce
    ; [rbp-40]=len
    ; [rbp-48]=i
    ; [rbp-56]=buf
    ; [rbp-64]=buf_ptr (offseted)

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

    mov qword [rbp-48], 0

.header_len_loop:
    mov rdi, [rbp-32]
    mov rdi, [rdi+HttpResponce.headers]
    mov rsi, [rbp-48]
    mov rdi, [rdi+rsi*8]
    test rdi, rdi
    jz .no_headers_len

    call strlen
    add [rbp-40], rax

    add qword [rbp-40], 2 ; add the lenght for the crlf
    
    inc qword [rbp-48]
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

    mov qword [rbp-48], 0

.header_str_loop:
    mov rdi, [rbp-32]
    mov rdi, [rdi+HttpResponce.headers]
    mov rsi, [rbp-48]
    mov rdi, [rdi+rsi*8]
    test rdi, rdi
    jz .no_headers_str

    call strlen
    
    mov rdi, [rbp-64]
    mov rsi, [rbp-32]
    mov rsi, [rsi+HttpResponce.headers]
    mov rdx, [rbp-48]
    mov rsi, [rsi+rdx*8]
    mov rdx, rax
    add qword [rbp-64], rax
    call memcpy

    mov rdi, [rbp-64]
    mov word [rdi], `\r\n`
    add qword [rbp-64], 2
    
    inc qword [rbp-48]
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
