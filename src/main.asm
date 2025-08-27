%include "helpers.inc"
%include "net.inc"
%include "http.inc"
%include "mem.inc"
%include "pages.inc"
%include "app.inc"
%include "linkedlist.inc"
%include "http_fields.inc"
%include "log.inc"

%define NOT_FOUND_BODY "404 Not Found"
%strlen NOT_FOUND_BODY_LEN NOT_FOUND_BODY

section .bss
    argc: resq 1
    argv: resq 1

section .data
    global argv
    global argc
    extern app

    start_msg: db "starting the server", 10, 0
    port_msg: db "port : ", 0
    not_found_str: db "Not Found", 0
    not_found_body: db NOT_FOUND_BODY
        .len equ NOT_FOUND_BODY_LEN
        .len_str db %str(NOT_FOUND_BODY_LEN), 0

    LL_STATIC not_found_headers, HttpHeader.size, not_found_content_lenght, not_found_connection
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
    port_arg: db "-p", 0
    help_arg: db "-h", 0
    help: db "My Http Web Server:", 10
    usage: db "usage : server [-p port][-h]", 10, 0
    arg_error: db "error: bad argument : ", 0
    port_arg_error: db "error: -p with no or an invalid port", 10, 0
    sigpipe_act:
        dq 1 ; sa_handler=SIG_ING
        dq 0 ; sa_sigaction should not be set when setting sa_handler
        times 128 db 0 ; sa_mask is 128 0s 
        dd 0 ; flags=0
        dq 0 ; sa_restorer=Null

section .text
    global _start
    global default_argument_parsing

_start:
    mov rdi, [rsp]
    mov [argc], rdi

    lea rsi, [rsp+8]
    mov [argv], rsi

    call main

    mov rdi, rax ; set the exit code to the value returned by main
    mov rax, 60 ; sys_exit
    syscall

default_argument_parsing:
    push rbp
    mov rbp, rsp

    sub rsp, 16
    mov qword [rbp-8], 1 ; [rbp-8]=current_arg
.loop:
    mov rdi, [rbp-8]
    cmp rdi, [argc]
    jge .end


    mov rsi, [argv]
    mov rdi, [rsi+rdi*8]
    lea rsi, [port_arg]
    call strcmp
    test rax, rax
    jz .port
    
    mov rsi, [argv]
    mov rdi, [rbp-8]
    mov rdi, [rsi+rdi*8]
    lea rsi, [help_arg]
    call strcmp
    test rax, rax
    jz .show_help

    lea rdi, [arg_error]
    call print

    mov rdi, [rbp-8]
    mov rsi, [argv]
    mov rdi, [rsi+rdi*8]
    call print

    mov dil, 10
    call putchar 

    lea rdi, [usage]
    call print

    mov rdi, 255
    call .exit
.show_help:
    lea rdi, [help]
    call print

    mov rdi, 0
.exit:
    mov rax, 60 ; sys_exit
    syscall 
.port:
    inc qword [rbp-8]
    mov rdi, [rbp-8]
    cmp rdi, [argc]
    jge .port_arg_error

    mov rsi, [argv]
    mov rdi, [rsi+rdi*8]
    call stoi

    cmp rax, 1<<16
    ja .port_arg_error

    mov [app+App.server_config+ServerConfig.port], ax 

    inc qword [rbp-8]
    jmp .loop
.port_arg_error:
    lea rdi, [port_arg_error]
    call print

    lea rdi, [usage]
    call print

    mov rdi, 255
    call .exit
.end:
    mov rsp, rbp
    pop rbp

    ret

main: ; () -> int
    ; setup the stack frame
    push rbp
    mov rbp, rsp

    sub rsp, 16 ; 16 bytes for variables
    ; [rbp-8] server

    call heap_init

    ; ignore sigpipe
    mov rax, 13 ; sys_rt_sigaction
    mov rdi, 13 ; SIGPIPE
    lea rsi, [sigpipe_act]
    xor rdx, rdx ; oldact=NULL
    syscall

    info s, start_msg

    call [app+App.init_callback]

    movbe di, [app+App.server_config+ServerConfig.port]
    movbe esi, [app+App.server_config+ServerConfig.address]
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
