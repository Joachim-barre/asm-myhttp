%include "helpers.inc"
%include "net.inc"
%include "http.inc"
%include "mem.inc"
%include "pages.inc"
%include "app.inc"
%include "linkedlist.inc"
%include "http_fields.inc"

%define NOT_FOUND_BODY "404 Not Found"
%strlen NOT_FOUND_BODY_LEN NOT_FOUND_BODY

section .data
    extern app

    start_msg: db "starting the server", 10, 0
    port_msg: db "port : ", 0
    not_found_str: db "Not Found", 0
    not_found_body: db NOT_FOUND_BODY
        .len equ NOT_FOUND_BODY_LEN
        .len_str db %str(NOT_FOUND_BODY_LEN)

    LL_STATIC not_found_headers, 8, not_found_content_lenght, not_found_connection
    LL_STATIC_NODE not_found_content_lenght, , not_found_connection, 0
    istruc HttpHeader
        at HttpHeader.field, dq content_lenght
        at HttpHeader.value, dq not_found_body.len_str
    iend
    LL_STATIC_NODE not_found_connection, , 0, not_found_content_lenght
    istruc HttpHeader
        at HttpHeader.field, dq connection
        at HttpHeader.value, dq connection_close
    iend

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
    mov qword [rbp-48+HttpResponce.headers], not_found_headers
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
