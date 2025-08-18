struc App
    .init_callback: resq 1 ; fn() called before the http server initalialisation
    .send_wrapper: resq 1 ; fn(u32, HttpRequest*, bool) that is called to send requests
    .size:
endstruc

%macro APP_DEFAULT 0
section .text
    required send_with_default_headers

    dummy:
        ret
section .data
    global app    

    app: istruc App
        at .init_callback, dq dummy
        at .send_wrapper, dq send_with_default_headers
    iend
%endmacro
