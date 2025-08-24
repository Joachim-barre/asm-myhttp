%include "app.inc"
%include "thread.inc"
%include "helpers.inc"
%include "log.inc"

section .data
    global app

    app: istruc App
        at .init_callback, dq init_callback
        at .send_wrapper, dq send_with_default_headers
    iend

section .text
    required send_with_default_headers
    global events_callback

init_callback:
    push rbp
    mov rbp, rsp

    info is, {"Initalizing the main app thread", 10}

    mov rdi, app_main
    mov rsi, 0
    call thread_init

    mov rsp, rbp
    pop rbp

    ret

app_main:
    push rbp
    mov rbp, rsp

    info is, {"the app's main thread is running", 10}

    mov rsp, rbp
    pop rbp

    ret

events_callback: ;  (HttpRequest*, int fd)
    ret ; TODO
