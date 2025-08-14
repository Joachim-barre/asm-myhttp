%define HTTP_SYMBOLS
%include "http.inc"
%include "net.inc"
%include "mem.inc"
%include "helpers.inc"

section .bss
    global http_server

    http_server equ server

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

    sub rsp, 16
    mov [rbp-8], rdi ; [rbp-8]=fd
    ; [rbp-16]=buf

    mov rdi, 1024
    call malloc

    mov [rbp-16], rax

    ; read a request
    mov rax, 0 ; sys_read
    mov edi, [rbp-8] ; fd
    mov rsi, [rbp-16] ; buf
    mov rdx, 1023 ; len=1023 (leave one char to the 0 terminator)
    syscall

    test rax, rax
    js .error

    ; print the request

    ; zero terminate the string
    mov rdi, [rbp-16]
    mov byte [rdi+rax], 0

    ; print the string
    call print

    jmp .exit

.error:
    mov rdi, rax
    call printi

.exit:
    mov rsp, rbp
    pop rbp

    ret
