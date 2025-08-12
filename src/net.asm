%define NET_SYMBOLS
%include "net.inc"
%include "helpers.inc"

section .bss
    global server
    global server_addr

    server: resb Server.size
    server_addr: resb SockAddr.size


section .text
    global server_init

; initalise the server
; port must be in big endian
server_init: ; (u16 port, u32 addr) -> Server*
    push rbp
    mov rbp, rsp

    sub rsp, 16 ; make room for 16 bytes of variables

    mov dword [server_addr + SockAddr.familly], 2 ; ipv4
    mov [server_addr + SockAddr.port], di
    mov [server_addr + SockAddr.addr], esi

    mov qword [server + Server.addr], server_addr

    mov rax, 41 ; sys_socket
    mov edi, 2 ; familly = AF_INET (ipv4)
    mov esi, 1 ; type=1 (stream)
    xor edx, edx ; protocol=0 (tcp)
    syscall

    mov [server + Server.sockfd], eax;

    mov rax, 49 ; sys_bind
    mov edi, [server + Server.sockfd] ; fd=server->sockfd
    mov rsi, [server + Server.addr] ; sokaddr=server->sockaddr
    mov edx, SockAddr.size ; edx=sizeof(SockAddr)
    syscall

    ; if the port is zero: store the real port in server->addr
    mov di, [server_addr + SockAddr.port]
    
    test di, di
    jnz .exit

    mov rax, 51 ; sys_getsockname
    mov edi, [server + Server.sockfd] ; fd=server->sockfd
    mov rsi, [server + Server.addr] ; addr=server->addr
    ; store the lenght on the stack
    lea rdx, [rbp-8] 
    mov qword [rdx], SockAddr.size
    syscall

.exit:
    lea rax, [server]

    mov rsp, rbp
    pop rbp

    ret
