; HttpServer is currently just Server, that might change

%ifndef HTTP_SYMBOLS
section .text
    extern http_init
    extern http_main_loop

section .bss
    extern http_server
%endif
