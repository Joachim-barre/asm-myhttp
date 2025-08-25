%include "app.inc"
%include "thread.inc"
%include "helpers.inc"
%include "log.inc"
%include "linkedlist.inc"
%include "http.inc"
%include "http_fields.inc"

section .data
    global app

    app: istruc App
        at .init_callback, dq init_callback
        at .send_wrapper, dq send_with_default_headers
    iend

    no_content_code equ 204
    no_content_str: db "No Content", 0
        .len equ $- no_content_str-1

    LL_STATIC send_headers, HttpHeader.size, send_connection_header, send_connection_header
    LL_STATIC_NODE send_connection_header, , 0, 0
    istruc HttpHeader
        at HttpHeader.field, dq connection
        at HttpHeader.value, dq connection_keep_alive
    iend

    send_responce: istruc HttpResponce
        at .status_code, dd no_content_code
        at .status_str, dq no_content_str
        at .headers, dq send_headers
        at .body, dq 0
    iend

section .text
    required send_with_default_headers
    global events_callback
    global send_callback

init_callback:
    push rbp
    mov rbp, rsp

    info is, "Initalizing the main app thread", c, 10

    mov rdi, app_main
    mov rsi, 0
    call thread_init

    mov rsp, rbp
    pop rbp

    ret

app_main:
    push rbp
    mov rbp, rsp

    info is, "the app's main thread is running", c, 10

    mov rsp, rbp
    pop rbp

    ret

events_callback: ;  (HttpRequest*, int fd)
    ret ; TODO

send_callback: ; (HttpRequest*, int fd)
    push rbp
    mov rbp, rsp

    sub rsp, 32
    mov [rbp-8], rdi   ; [rbp-8]=request
    mov [rbp-12], esi  ; [rbp-12]=fd
    ; [rbp-24]=message

    mov rdi, [rdi+HttpRequest.body]
    test rdi, rdi
    jz .no_body

    ; ignore empty message
    mov rsi, [rdi+HttpBody.len]
    test rsi, rsi
    jz .no_body

    ; log the message
    mov rdi, [rdi+HttpBody.ptr]
    mov [rbp-24], rdi

    info is, "recived message : ", sp, [rbp-24], c, 10
.no_body:
    mov edi, [rbp-12]
    lea rsi, [send_responce]
    call http_send_responce

    mov rsp, rbp
    pop rbp
    ret
