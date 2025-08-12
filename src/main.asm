section .data
    hello_msg: db "Hello World!", 10, 0
        .len equ $- hello_msg

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

    mov rax, 1 ; sys_write
    mov rdi, 1 ; fd=1 (stdout)
    lea rsi, [hello_msg] ; buf=hello_msg
    mov rdx, hello_msg.len ; count=hello_msg.len
    syscall

    mov rax, 0 ; exit with code 0 (success)

    ; exit the stack frame
    mov rsp, rbp
    pop rbp

    ret
