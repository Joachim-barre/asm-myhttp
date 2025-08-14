; HttpServer is currently just Server, that might change

struc HttpRequest
    .method: resq 1 ; char *
    .path: resq 1 ; char *
    .ver: resq 1 ; char *
    .headers: resq 1 ; char**
    .body : resq 1 ; char*
    .size: ; should stay 40
endstruc

struc HttpResponce
    .status_code : resd 1 ; int
    .pad: resd 1
    .status_str : resq 1 ; char*
    .headers: resq 1 ; char**
    .body: resq 1 ; char*
    .size: ; should stay 32
endstruc

%ifndef HTTP_SYMBOLS
section .text
    extern http_init
    extern http_main_loop
    extern http_send_responce

section .bss
    extern http_server
%endif
