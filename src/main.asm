%include "helpers.inc"
%include "net.inc"
%include "heap.inc"

section .data
    start_msg: db "starting the server", 10, 0
    port_msg: db "port : ", 0

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

    mov di, 0 ; let the os choose the port
    mov esi, 0 ; all interfaces
    call server_init

    mov [rbp-8], rax

    lea rdi, [port_msg]
    call print

    mov rdi, [rbp-8]
    mov rdi, [rdi+Server.addr]
    mov ax, [rdi+SockAddr.port]
    
    xchg ah, al ; swap the endianess
    movzx edi, ax ; convert the port value to 32 bit
    call printi

    mov dil, 10 ; newline
    call putchar

    lea rax, [server_callback]
    call server_main_loop

    ; exit the stack frame
    mov rsp, rbp
    pop rbp

    ret

server_callback:
    ret
