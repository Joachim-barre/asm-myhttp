%include "helpers.inc"
%include "net.inc"
%include "http.inc"
%include "mem.inc"
%include "pages.inc"
%include "app.inc"

section .data
    extern app

    start_msg: db "starting the server", 10, 0
    port_msg: db "port : ", 0
    bad_request_str: db "Bad Request", 0
    bad_request_body: db "400 Bad Request"
        .len equ $- bad_request_body
    not_found_str: db "Not Found", 0
    not_found_body: db "404 Not Found"
        .len equ $- not_found_body

section .text
    global _start

_start:

    call main

    mov rdi, rax ; set the exit code to the value returned by main
    mov rax, 60 ; sys_exit
    syscall

main: ; () -> int
    ; setup the stack frame
    push rbp
    mov rbp, rsp

    sub rsp, 16 ; 16 bytes for variables
    ; [rbp-8] server

    call heap_init

    mov rdi, start_msg
    call print

    call [app+App.init_callback]

    mov di, 0 ; let the os choose the port
    mov esi, 0 ; all interfaces
    lea rdx, [request_handler]
    call http_init

    mov [rbp-8], rax

    lea rdi, [port_msg]
    call print

    mov rdi, [server+Server.addr]
    mov ax, [rdi+SockAddr.port]
    
    xchg ah, al ; swap the endianess
    movzx edi, ax ; convert the port value to 32 bit
    call printi

    mov dil, 10 ; newline
    call putchar

    call http_main_loop

    ; exit the stack frame
    mov rsp, rbp
    pop rbp

    ret

request_handler: ; (i32 fd, HttpRequest*) -> bool
    push rbp
    mov rbp, rsp

    sub rsp, 64 ; make room for vars
    mov [rbp-8], rsi ; [rbp-8]=request
    mov [rbp-12], edi ; [rbp-12]=fd
    ; [rbp-48] responce
    ; [rbp-64] body

    mov rdi, [rbp-8]
    mov rsi, [rbp-12]
    call find_page

    test rax, rax
    jz .not_found

    mov rax, rdx
    jmp .exit
.not_found:
    mov dword [rbp-48+HttpResponce.status_code], 404
    mov qword [rbp-48+HttpResponce.status_str], not_found_str
    mov qword [rbp-48+HttpResponce.headers], 0
    lea rax, [rbp-64]
    mov qword [rbp-48+HttpResponce.body], rax
    mov qword [rax+HttpBody.ptr], not_found_body
    mov qword [rax+HttpBody.len], not_found_body.len

    mov edi, [rbp-12]
    lea rsi, [rbp-48]
    call http_send_responce

    xor rax, rax
.exit:
    mov rsp, rbp
    pop rbp

    ret
