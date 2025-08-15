%define PAGES_SYMBOLS
%include "pages.inc"
%include "helpers.inc"

section .data
    global pages

    pages: dq index, 0 ; Page** (page array)

    index: istruc Page
        at Page.path, dq index_path
        at Page.data, dq index_data
    iend

    index_path: db "/", 0
    index_data: incbin "html/index.html" db 0

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
