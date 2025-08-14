%define HTTP_SYMBOLS
%include "http.inc"
%include "net.inc"

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

    ; TODO 

    mov rsp, rbp
    pop rbp

    ret
