%include "http.inc"
%include "mem.inc"

section .data
    ok_str: db "OK", 0

section .text
    global encode
    global decode

; read utf8 codepoint not unicode char
utf8_next_char: ; (char*) -> (u32, char*)
    push rbp
    mov rbp, rsp

    mov sil, [rdi]
    test sil, 0x80
    jz .ascii

    mov sil, [rdi]
    and sil, 0xE0
    cmp sil, 0xC0
    je .2bytes

    mov sil, [rdi]
    and sil, 0xF0
    cmp sil, 0xE0
    je .3bytes

    
    mov sil, [rdi]
    and sil, 0xF8
    cmp sil, 0xF0
    je .4bytes
.invalid:
    mov rax, 0

    jmp .exit
.4bytes:
    mov cx, [rdi+2]
    and cl, 0xC0
    cmp cl, 0x80
    jne .invalid

    and ch, 0xC0
    cmp ch, 0x80
    jne .invalid

    mov cl, [rdi+1]
    and cl, 0xC0
    cmp cl, 0x80
    jne .invalid

    mov eax, [rdi]
    lea rdx, [rdi+4]
    jmp .exit
.3bytes:
    mov dx, [rdi+1]
    mov cx, dx
    and cl, 0xC0
    cmp cl, 0x80
    jne .invalid

    and ch, 0xC0
    cmp ch, 0x80
    jne .invalid
  
    movzx eax, dx
    mov cl, [rdi]
    movzx ecx, cl
    shl ecx, 16
    or eax, ecx

    lea rdx, [rdi+3]
    jmp .exit
.2bytes:
    mov ax, [rdi]
    mov cl, ah
    and cl, 0xC0
    cmp cl, 0x80
    jne .invalid

    lea rdx, [rdi+2]
    jmp .exit
.ascii:
    movzx rax, sil
    lea rdx, [rdi+1]
.exit:
    mov rsp, rbp
    pop rbp

    ret

encode: ; (HttpRequest*, int fd)
    push rbp
    mov rbp, rsp

    sub rsp, 64
    ; [rbp-32] responce
    ; [rbp-48] body
    ; [rbp-56] str
    mov dword [rbp-60], esi ; [rbp-60]=fd
    mov dword [rbp-64], 0; [rbp-64]=body_offset

    mov rdi, [rdi+HttpRequest.body]
    mov rsi, [rdi+HttpBody.ptr]
    mov [rbp-56], rsi

    mov rdi, [rdi+HttpBody.len]
    lea rdi, [rdi*4]
    call malloc

    mov [rbp-48+HttpBody.ptr], rax
    mov dword [rbp-48+HttpBody.len], 0

.loop:
    mov rdi, [rbp-56]
    call utf8_next_char
    mov [rbp-56], rdx

    test eax, eax
    jz .end

    cmp eax, 0xFF
    jbe .ascii

    mov al, '?'
    mov rdi, [rbp-48+HttpBody.ptr]
    mov esi, [rbp-64]
    mov [rdi+rsi], al
    inc dword [rbp-64]
    
    jmp .loop
.ascii:
    mov ecx, 0b00111111
    and ecx, eax
    and eax, 0b11000000
    shl eax, 2
    or eax, ecx
    or eax, 0xf09f9480

    bswap eax

    mov rdi, [rbp-48+HttpBody.ptr]
    mov esi, [rbp-64]
    mov [rdi+rsi], eax
    add dword [rbp-64], 4

    jmp .loop
.end:
    mov dword [rbp-32+HttpResponce.status_code], 200
    mov qword [rbp-32+HttpResponce.status_str], ok_str
    mov qword [rbp-32+HttpResponce.headers], 0
    lea rax, [rbp-48]
    mov qword [rbp-32+HttpResponce.body], rax
    mov edi, [rbp-64]
    mov  [rax+HttpBody.len], rdi
    
    mov edi, [rbp-60]
    lea rsi, [rbp-32]
    call http_send_responce

    mov rdi, [rbp-48+HttpBody.ptr]
    call free

    mov rsp, rbp
    pop rbp
    
    ret

decode: ; (HttpRequest*, int fd)
    ; TODO
    ret
