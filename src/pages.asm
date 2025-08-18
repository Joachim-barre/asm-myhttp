%define PAGES_SYMBOLS
%include "pages.inc"
%include "helpers.inc"
%include "http.inc"

section .data
    extern pages

    ok_str: db "OK", 0


    find_page_jmp_tbl:
        dq find_page.kind_str
        dq find_page.kind_bin
        dq find_page.kind_fn

section .text
    global find_page

; find a page and execute a callback
; first returned value is true if found
; the second is true if the connection should be kept alive
find_page: ; (HttpRequest*, int fd) -> bool
    push rbp
    mov rbp, rsp

    sub rsp, 80 ; make rooms for vars
    mov qword [rbp-8], pages ; [rbp-8]=i
    mov rdx, [rdi+HttpRequest.path]
    mov [rbp-16], rdx ; [rbp-16]=path
    mov [rbp-24], rdi ; [rbp-24]=req
    mov [rbp-30], esi ; [rbp-30]=fd
    ; [rbp-64]=responce
    ; [rbp-80]=body

.loop:
    mov rdi, [rbp-8]
    mov rdi, [rdi]
    test rdi, rdi
    jz .not_found

    mov rdi, [rdi+Page.path]
    mov rsi, [rbp-16]
    call strcmp

    test rax, rax
    jnz .inc_pointer
    
    mov rdi, [rbp-8]
    mov rdi, [rdi]
    mov rdi, [rdi+Page.method]
    mov rsi, [rbp-24]
    mov rsi, [rsi+HttpRequest.method]
    call strcmp

    test rax, rax
    jz .found

.inc_pointer:
    add qword [rbp-8], 8
    jmp .loop
  
.found:
    mov rdi, [rbp-8]
    mov rdi, [rdi]
    mov rax, [rdi+Page.kind]
    cmp rax, 3
    jae .not_found ; ignore page if kind is invalid
    mov rsi, [find_page_jmp_tbl+rax*8]
    jmp rsi

.kind_str: 
    mov dword [rbp-64+HttpResponce.status_code], 200
    mov qword [rbp-64+HttpResponce.status_str], ok_str
    mov qword [rbp-64+HttpResponce.headers], 0
    lea rax, [rbp-80]
    mov qword [rbp-64+HttpResponce.body], rax
    mov rsi, [rdi+Page.data0]
    mov [rax+HttpBody.ptr], rsi
    
    mov rdi, rsi
    call strlen

    mov [rbp-80+HttpBody.len], rax

    mov edi, [rbp-30]
    lea rsi, [rbp-64]
    mov edx, 1
    call send_with_default_headers

    mov rax, 1
    mov rdx, 1
    jmp .exit
    
.kind_bin:
    mov dword [rbp-64+HttpResponce.status_code], 200
    mov qword [rbp-64+HttpResponce.status_str], ok_str
    mov qword [rbp-64+HttpResponce.headers], 0
    lea rax, [rbp-80]
    mov qword [rbp-64+HttpResponce.body], rax
    mov rsi, [rdi+Page.data0]
    mov [rax+HttpBody.ptr], rsi
    mov rsi, [rdi+Page.data1]
    mov [rax+HttpBody.len], rsi

    mov edi, [rbp-30]
    lea rsi, [rbp-64]
    mov edx, 1
    call send_with_default_headers

    mov rax, 1
    mov rdx, 1
    jmp .exit

.kind_fn:
    mov rax, [rdi+Page.data0]
    mov rdi, [rbp-24]
    mov esi, [rbp-30]
    call rax

    mov rdx, rax
    mov rax, 1
    jmp .exit

.not_found:
    mov rax, 0
.exit:
    mov rsp, rbp
    pop rbp

    ret
