%include "helpers.inc"

section .data
    hello_msg: db "Hello World!", 10, 0

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

    mov rdi, hello_msg
    call print

    mov rdi, 1234
    call printi

    mov dil, 10
    call putchar

    mov rax, 0 ; exit with code 0 (success)

    ; exit the stack frame
    mov rsp, rbp
    pop rbp

    ret
