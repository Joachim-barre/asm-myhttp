%define NET_SYMBOLS
%include "net.inc"
%include "helpers.inc"
%include "thread.inc"

section .bss
    global server
    global server_addr

    server: resb Server.size
    server_addr: resb SockAddr.size

section .data
    connection_msg: db "Accepting connection from : ", 0
    disconnection_msg: db "Closing connection with : ", 0

section .text
    global server_init
    global print_ip_port
    global server_main_loop

; initalise the server
; port must be in big endian
server_init: ; (u16 port, u32 addr, handler(u32 fd)) -> Server*
    push rbp
    mov rbp, rsp

    sub rsp, 16 ; make room for 16 bytes of variables

    mov [server + Server.handler], rdx

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

    movzx edi, byte [rbp+rax-5]
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
server_main_loop:
    push rbp
    mov rbp, rsp

    mov rax, 50 ; sys_listen
    mov edi, [server+Server.sockfd] ; fd=server->sockfd
    mov esi, 5 ; backlog of 5 packets
    syscall

.loop:
    mov rax, 43 ; sys_accept
    mov edi, [server+Server.sockfd] ;fd=server->sockfd
    mov rsi, 0 ; addr=Null
    mov rdx, 0 ; len=Null
    syscall

    test eax, eax
    js .exit

    ; start a thread for the callback
    lea rdi, [server_child_handler]
    mov rsi, rax
    call thread_init

    ; parent process : loop again

    jmp .loop

.exit:
    mov rsp, rbp
    pop rbp

    ret

server_child_handler: ; (u64 fd (zero extended))
    push rbp
    mov rbp, rsp

    sub rsp, 32 ; make room for vars
    ; [rbp-16]=sockaddr
    mov qword [rbp-24], 16 ; [rbp-24]=len
    mov [rbp-28], edi ; [rbp-28]=fd

    ; read the sockaddr
    mov rax, 51 ; sys_getsockname
    mov edi, [rbp-28] ; fd=fd
    lea rsi, [rbp-16] ; sockaddr=&sockaddr
    lea rdx, [rbp-24] ; len=&len
    syscall

    ; log the request
    lea rdi, [connection_msg]
    call print

    mov edi, [rbp-16+SockAddr.addr]
    mov si, [rbp-16+SockAddr.port]
    call print_ip_port

    mov dil, 10
    call putchar

    mov edi, [rbp-28]
    mov rax, [server+Server.handler]
    call rax

    ; log the request
    lea rdi, [disconnection_msg]
    call print

    mov edi, [rbp-16+SockAddr.addr]
    mov si, [rbp-16+SockAddr.port]
    call print_ip_port

    mov dil, 10
    call putchar

    ; close the connection
    mov rax, 3 ; sys_close
    mov edi, [rbp-28] ; fd
    syscall

    mov rsp, rbp
    pop rbp

    ret
    
