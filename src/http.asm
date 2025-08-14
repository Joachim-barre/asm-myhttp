%define HTTP_SYMBOLS
%include "http.inc"
%include "net.inc"
%include "mem.inc"
%include "helpers.inc"

section .bss
    global http_server

    http_server equ server

section .data
    recived_msg: db "recived request: ", 0

section .text
    global http_init
    global http_main_loop

http_init: ; (u16 port, u32 address) -> HttpServer*
    push rbp ; align the stack

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
