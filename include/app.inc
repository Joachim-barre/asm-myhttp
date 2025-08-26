struc ServerConfig
    .port: resw 1 ; the port in little endian
    .address: resd 1 ; the ip address used by the server
    .size:
endstruc 

struc App
    .init_callback: resq 1 ; fn() called before the http server initalialisation
    .send_wrapper: resq 1 ; fn(u32, HttpRequest*, bool) that is called to send requests
    .server_config: resb ServerConfig.size 
    .size:
endstruc

%macro APP_DEFAULT 0
section .text
    required send_with_default_headers
    required default_argument_parsing
section .data
    global app    

    app: istruc App
        at .init_callback, dq default_argument_parsing
        at .send_wrapper, dq send_with_default_headers
        at .server_config, istruc ServerConfig
            at .port, dw 0
            at .address, dd 0
        iend
    iend
%endmacro
