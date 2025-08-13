struc SockAddr
    .familly: resw 1
    .port: resw 1
    .addr: resd 1
    .pad: resb 8
    .size:
endstruc

struc Server
    .addr: resq 1
    .sockfd: resd 1
    .size:
endstruc

%ifndef NET_SYMBOLS
section .text
    extern server_init
    extern print_ip_port
    extern server_main_loop

section .bss
    extern server
    extern sever_addr
%endif
