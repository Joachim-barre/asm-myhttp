; HttpServer is currently just Server, that might change

struc HttpRequest
    .method: resq 1 ; char *
    .path: resq 1 ; char *
    .ver: resq 1 ; char *
    .headers: resq 1 ; LinkedList* (Item=HttpHeader)
    .body : resq 1 ; HttpBody*
    .size: ; should stay 40
endstruc

struc HttpResponce
    .status_code : resd 1 ; int
    .pad: resd 1
    .status_str : resq 1 ; char*
    .headers: resq 1 ; LinkedList* (Item=HttpHeader)
    .body: resq 1 ; HttpBody*
    .size: ; should stay 32
endstruc

struc HttpBody
    .ptr: resq 1
    .len: resq 1
    .size: ; should stay 16
endstruc

struc HttpHeader
    .field: resq 1; char*
    .value: resq 1; char*
    .size:
endstruc

%ifndef HTTP_SYMBOLS
section .text
    extern http_init
    extern http_main_loop
    extern http_send_responce
    extern send_with_default_headers
    extern send_bad_request

section .bss
    extern http_server
%endif
