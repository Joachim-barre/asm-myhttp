%define NET_SYMBOLS
%include "net.inc"
%include "helpers.inc"

section .bss
    global server
    global server_addr

    server: resb Server.size
    server_addr: resb SockAddr.size

section .data
    connection_msg: db "Accepting connection from : ", 0

section .text
    global server_init
    global print_ip_port
    global server_main_loop

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

print_ip_port: ; (i32 ip, i16 port)
    push rbp
    mov rbp, rsp

    sub rsp, 16 ; make space to save args
    mov [rbp-4], edi; [rbp-4] ip
    mov [rbp-6], si ; [rbp-6] port
    mov word [rbp-8], 0 ; [rbp-8] i

.ip_loop:
    inc word [rbp-8]
    movzx rax, word [rbp-8]
    neg rax

    movzx edi, byte [rbp+rax]
    call printi

    cmp word [rbp-8], 4
    jge .ip_loop_end

    mov dil, '.'
    call putchar

    jmp .ip_loop

.ip_loop_end:
    mov dil, ':'
    call putchar

    movzx edi, word [rbp-6]
    call printi

    mov rsp, rbp
    pop rbp

    ret

; listen to incoming connection and call the callback in a child process when a connection start
; returns only on error
server_main_loop: ; (callback(i32 sockfd, *SockAddr))
    push rbp
    mov rbp, rsp

    sub rsp, 32 ; make space for vars
    ; [rbp-16] sock_addr
    ; [rbp-24] len in parent and fd in child
    ; [rbp-32] callback

    mov rax, 50 ; sys_listen
    mov edi, [server+Server.sockfd] ; fd=server->sockfd
    mov esi, 5 ; backlog of 5 packets
    syscall

.loop:
    mov qword [rbp-24], 16 ; len = 16

    mov rax, 43 ; sys_accept
    mov edi, [server+Server.sockfd] ;fd=server->sockfd
    lea rsi, [rbp-16] ; addr=&sock_addr
    lea rdx, [rbp-24] ; len=&len
    syscall

    test eax, eax
    js .exit

    mov [rbp-24], eax ; save fd

    ; start a child for the callback
    mov rax, 57 ; sys_fork
    syscall

    test eax, eax ; pid is zero only for child
    jz .child

    ; parent process :
    ; close the connection socket and loop again
    mov rax, 3 ; sys_close
    mov edi, [rbp-24] ; fd=fd
    syscall 

    jmp .loop

.child:
    ; close main server socket
    mov rax, 3 ; sys_close
    mov rdi, [server+Server.sockfd] ; fd=server->sockfd
    syscall

    ; log the request
    lea rdi, [connection_msg]
    call print

    mov edi, [rbp-16+SockAddr.addr]
    mov si, [rbp-16+SockAddr.port]
    call print_ip_port

    mov dil, 10
    call putchar

    ; call the callback
    mov edi, [rbp-24]
    lea rsi, [rbp-16]
    mov rax, [rbp-32]
    call [rax]

    ; callback ended exit child 
    mov rax, 60 ; sys_exit
    mov rdi, 0
    syscall

.exit:
    mov rsp, rbp
    pop rbp

    ret
