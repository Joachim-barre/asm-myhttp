%define PAGES_SYMBOLS
%include "pages.inc"
%include "helpers.inc"

section .data
    extern pages

section .text
    global find_page

find_page: ; (char* path) -> char*
    push rbp
    mov rbp, rsp

    sub rsp, 16 ; make rooms for vars
    mov qword [rbp-8], pages ; [rbp-8]=i
    mov [rbp-16], rdi ; [rbp-16]=path

.loop:
    mov rdi, [rbp-8]
    mov rdi, [rdi]
    test rdi, rdi
    jz .not_found

    mov rdi, [rdi+Page.path]
    mov rsi, [rbp-16]
    call strcmp

    test rax, rax
    jz .found

    add qword [rbp-8], 8
    jmp .loop
  
.found:
    mov rax, [rbp-8]
    mov rax, [rax]
    mov rax, [rax+Page.data]
    jmp .exit

.not_found:
    mov rax, 0
.exit:
    mov rsp, rbp
    pop rbp

    ret
