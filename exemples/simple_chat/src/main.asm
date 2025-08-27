%include "app.inc"
%include "thread.inc"
%include "helpers.inc"
%include "log.inc"
%include "linkedlist.inc"
%include "http.inc"
%include "http_fields.inc"
%include "mem.inc"

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

    ok_code equ 200
    ok_str: db "Ok", 0
        .len equ $- ok_str-1

    content_type: db "Content-Type", 0
    event_stream: db "text/event-stream", 0

    LL_STATIC events_headers, HttpHeader.size, events_connection_header, events_content_type
    LL_STATIC_NODE events_connection_header, , events_content_type, 0
    istruc HttpHeader
        at HttpHeader.field, dq connection
        at HttpHeader.value, dq connection_keep_alive
    iend

    LL_STATIC_NODE events_content_type, , 0, events_connection_header
    istruc HttpHeader
        at HttpHeader.field, dq content_type
        at HttpHeader.value, dq event_stream
    iend

    events_responce: istruc HttpResponce
        at .status_code, dd ok_code
        at .status_str, dq ok_str
        at .headers, dq events_headers
        at .body, dq 0
    iend

section .bss
    listeners: resb SpinLock.size ; SpinLock<LinkedList<Fd>>

    listeners_inner: resb LinkedList.size

    message: resq 2 ; (char*, u64)
    message_state: resd 1 ; int -> 0 == available for write, 1 == writing, 2 == ready to read

section .text
    required send_with_default_headers
    extern default_argument_parsing
    global events_callback
    global send_callback

init_callback:
    push rbp
    mov rbp, rsp

    call default_argument_parsing

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

    sub rsp, 48
    ; [rbp-32] responce
    ; [rbp-48] body

    info is, "the app's main thread is running", c, 10

    lea rdi, [listeners_inner]
    mov rsi, 4
    call ll_init

    lea rdi, [listeners]
    lea rsi, [listeners_inner]
    call spin_init

    mov dword [message_state], 0
.loop:
    mov edi, [message_state]
    cmp edi, 2
    jne .loop

    lea rdi, [listeners]
    call spin_lock

    info is, "sending the message to the clients : ", sp, [message], c, 10
    
    ; TODO

    mov rdi, [message]
    call free

    lea rdi, [listeners]
    call spin_unlock
    
    mov dword [message_state], 0

    jmp .loop

    mov rsp, rbp
    pop rbp

    ret

events_callback: ;  (HttpRequest*, int fd)
    push rbp
    mov rbp, rsp

    sub rsp, 16
    mov [rbp-8], rdi
    mov [rbp-12], esi

    info is, "Initalizing SSE connection", c, 10

    mov edi, [rbp-12]
    lea rsi, [events_responce]
    call http_send_responce

    ; duplicate the file handle
    mov rax, 32
    mov edi, [rbp-12]
    syscall

    mov [rbp-12], eax

    lea rdi, [listeners]
    call spin_lock

    mov rdi, rax
    lea rsi, [rbp-12]
    call ll_push_back

    lea rdi, [listeners]
    call spin_unlock

    ; terminate the handler
    xor rax, rax

    mov rsp, rbp
    pop rbp

    ret

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
.wait_loop:
    mov eax, 0
    mov edi, 1
    lock cmpxchg [message_state], edi

    jnz .wait_loop ; ZF=0 if cmpxchg fails

    ; copy the data to another buffer
    mov rdi, [rbp-8]
    mov rdi, [rdi+HttpRequest.body]
    mov rdi, [rdi+HttpBody.len]
    mov [message+8], rdi ; save the lenght
    call malloc

    mov [message], rax ; save the pointer

    ; copy the data
    mov rdi, rax
    mov rsi, [rbp-8]
    mov rsi, [rsi+HttpRequest.body]
    mov rsi, [rsi+HttpBody.ptr]
    mov rdx, [message+8]
    call memcpy

    ; mark as read ready
    mov dword [message_state], 2
.no_body:
    mov edi, [rbp-12]
    lea rsi, [send_responce]
    call http_send_responce

    mov rsp, rbp
    pop rbp
    ret
