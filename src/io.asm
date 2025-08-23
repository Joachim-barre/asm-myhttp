%define IO_SYMBOLS
%include "io.inc"
%include "mem.inc"
%include "helpers.inc"

section .text
    global bfr_init
    global bfr_free
    global bfr_close
    global bfr_peek
    global bfr_read
    global bfr_read_all
    global bfr_read_until
    global bfr_fill_buf
    global bfr_skip

bfr_init:
    push rbp
    mov rbp, rsp

    sub rsp, 16
    mov [rbp-8], rdi ; [rbp-8]=self

    mov [rdi+BufferedFileReader.fd], esi
    mov dword [rdi+BufferedFileReader.buffer_size], BFR_INITIAL_BUFSIZE
    mov dword [rdi+BufferedFileReader.buffer_offset], 0
    mov dword [rdi+BufferedFileReader.buffer_data_size], 0

    mov rdi, BFR_INITIAL_BUFSIZE
    call malloc

    mov rdi, [rbp-8]
    mov [rdi+BufferedFileReader.buffer], rax

    mov rsp, rbp
    pop rbp

    ret

bfr_free:
    push rbp
    mov rbp, rsp

    mov rdi, [rdi+BufferedFileReader.buffer]
    call free
    
    mov rsp, rbp
    pop rbp

    ret

bfr_close:
    push rbp
    mov rbp, rsp

    sub rsp, 16
    mov [rbp-8], rdi ; [rbp-8]=self

    call bfr_free
    
    mov rax, 3 ; sys_close
    mov rdi, [rbp-8]
    mov edi, [rdi+BufferedFileReader.fd]
    syscall

    mov rsp, rbp
    pop rbp

    ret

; tries to read more data
; extends the allocation to be able to store at least len more bytes
; return 0 on eof, and a negative value on error
bfr_try_read_more: ; (BufferedFileReader*, u32 len) -> i32
    push rbp
    mov rbp, rsp

    sub rsp, 32
    mov [rbp-8], rdi ; [rbp-8]=self
    mov [rbp-12], esi ; [rbp-16]=len
    ; [rbp-24]=old_buf

    ; check that we can store at least the expected data size
    mov edx, [rdi+BufferedFileReader.buffer_data_size]
    add edx, esi
    jc .efbig
    cmp edx, BFR_MAX_BUFSIZE
    ja .efbig

    ; check if we need to extend the allocation
    ; edx already contains the minimum size that the buffer should have
    mov ecx, [rdi+BufferedFileReader.buffer_size]
    cmp edx, ecx
    ja .extend_alloc

    ; compute the capacity
    mov edx, [rdi+BufferedFileReader.buffer_size]
    sub edx, [rdi+BufferedFileReader.buffer_offset]
    sub edx, [rdi+BufferedFileReader.buffer_data_size]
    cmp edx, esi
    jge .correct_size

    ; moving the data to the begining of the buffer is enough
    
    ; check if there is data that needs to be moved
    mov edx, [rdi+BufferedFileReader.buffer_data_size]
    test edx, edx
    jz .no_data

    ; move the data
    ; rdx is already the data size
    mov esi, [rdi+BufferedFileReader.buffer_offset]
    add rsi, [rdi+BufferedFileReader.buffer]
    mov rdi, [rdi+BufferedFileReader.buffer]
    call memmove

    mov rdi, [rbp-8]
    jmp .no_data
.extend_alloc:
    ; allocate a new buffer
    
    ; compute the size
    mov edi, [rdi+BufferedFileReader.buffer_data_size]
    add rdi, rsi
    mov rsi, BFR_INITIAL_BUFSIZE
    call align_up ; keep the size a multiple of the initial size

    mov rdi, [rbp-8]
    mov [rdi+BufferedFileReader.buffer_size], eax ; update the buffer_size

    mov rdi, rax
    call malloc

    mov rdi, [rbp-8]
    mov rcx, rax
    xchg rcx, [rdi+BufferedFileReader.buffer]
    mov [rbp-24], rcx

    mov edx, [rdi+BufferedFileReader.buffer_data_size]
    xor esi, esi
    xchg esi, [rdi+BufferedFileReader.buffer_offset] ; load the offset and set the offset to zero at the same time
    add rsi, rcx
    mov rdi, rax
    call memcpy

    mov rdi, [rbp-8]
    jmp .correct_size
.no_data:
    mov dword [rdi+BufferedFileReader.buffer_offset], 0
.correct_size:
    ; read data from the end from the previous data
    xor rax, rax ; sys_read
    mov esi, [rdi+BufferedFileReader.buffer_data_size]
    add esi, [rdi+BufferedFileReader.buffer_offset]
    mov edx, [rdi+BufferedFileReader.buffer_size]
    sub rdx, rsi
    add rsi, [rdi+BufferedFileReader.buffer]
    mov edi, [rdi+BufferedFileReader.fd]
    syscall

    test rax, rax
    js .exit ; return the error
    jz .exit ; eof

    mov rdi, [rbp-8]
    add [rdi+BufferedFileReader.buffer_data_size], eax

    jmp .exit
.efbig:
    mov eax, EFBIG
.exit:
    mov rsp, rbp
    pop rbp

    ret

bfr_peek:
    push rbp
    mov rbp, rsp

    sub rsp, 32
    mov [rbp-8], rdi ; [rbp-8]=self
    mov [rbp-16], rsi ; [rbp-16]=buf
    mov [rbp-24], rdx ; [rbp-24]=len

    cmp rdx, BFR_MAX_BUFSIZE
    ja .einval

    mov ecx, [rdi+BufferedFileReader.buffer_data_size]
    test ecx, ecx
    jnz .enough_data

    mov esi, edx
    call bfr_try_read_more

    test eax, eax
    js .error
    jz .eof
    jmp .enough_data
.eof:
    xor rax, rax
    jmp .exit
.error:
    movsxd rax, eax
    jmp .exit
.einval:
    mov rax, EINVAL
    jmp .exit
.enough_data:
    mov rdi, [rbp-8]
    mov esi, [rdi+BufferedFileReader.buffer_data_size]
    mov rdx, [rbp-24]
    cmp rdx, rsi
    cmovae rdx, rsi
    mov [rbp-24], rdx

    mov esi, [rdi+BufferedFileReader.buffer_offset]
    add rsi, [rdi+BufferedFileReader.buffer]
    mov rdi, [rbp-16]
    call memcpy
.exit:
    mov rsp, rbp
    pop rbp

    ret

bfr_read:
    push rbp
    mov rbp, rsp

    sub rsp, 16
    mov [rbp-8], rdi ; [rbp-8]=self
    ; [rbp-16]=len

    call bfr_peek

    test rax, rax
    js .error
    jz .eof

    mov [rbp-16], rax
    mov rdi, [rbp-8]
    mov rsi, rax
    call bfr_skip

    test rax, rax
    js .error
    jz .eof

    mov rax, [rbp-16]
    jmp .exit   
.eof:
    xor rax, rax
    jmp .exit
.error:
.exit:
    mov rsp, rbp
    pop rbp

    ret

bfr_read_all:
    push rbp
    mov rbp, rsp

    sub rsp, 32
    mov [rbp-8], rdi ; [rbp-8]=self
    mov [rbp-16], rsi ; [rbp-16]=buf
    mov [rbp-24], rdx ; [rbp-24]=len
    mov qword [rbp-32], 0 ; [rbp-32]=offset
.loop:
    call bfr_read
    js .exit ; return the error on error
    jz .loop_end
    add qword [rbp-32], rax
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    add rsi, [rbp-32]
    cmp rsi, [rbp-24]
    jge .loop_end
    mov rdx, [rbp-24]
    sub rdx, [rbp-32]
    jmp .loop
.loop_end:
    mov rax, [rbp-32]
.exit:
    mov rsp, rbp
    pop rbp

    ret

bfr_read_until:
    push rbp
    mov rbp, rsp

    sub rsp, 32
    mov [rbp-8], rdi ; [rbp-8]=self
    mov edx, [rdi+BufferedFileReader.buffer_offset]
    mov [rbp-12], edx ; offset then size
    mov [rbp-13], sil ; [rbp-13]=chr
    ; [rbp-24]=buffer
.loop:
    mov rax, [rbp-8]
    mov edi, [rbp-12]
    add rdi, [rax+BufferedFileReader.buffer]
    mov sil, [rbp-13]
    mov edx, [rax+BufferedFileReader.buffer_data_size]
    add edx, [rax+BufferedFileReader.buffer_offset] ; since [rbp-12] include it but not data size
    sub edx, [rbp-12]
    add [rbp-12], edx ; update the offset
    call memchr

    test rax, rax
    jnz .found

    mov rdi, [rbp-8]
    mov esi, 1024
    call bfr_try_read_more
    js .error
    jz .eof
    jmp .loop
.eof:
    xor rax, rax
    xor rdx, rdx
    jmp .exit
.error:
    movsxd rax, eax
    mov rdx, 0
    jmp .exit
.found:
    mov rdx, [rbp-8]
    inc rax ; include the searched char

    mov edi, [rdx+BufferedFileReader.buffer_offset]
    neg rdi
    add rdi, rax
    sub rdi, [rdx+BufferedFileReader.buffer]
    mov [rbp-12], edi
    add rdi, 1 ; for null terminator
    call malloc

    mov [rbp-24], rax 

    mov rcx, [rbp-8]

    mov rdi, rax
    mov esi, [rcx+BufferedFileReader.buffer_offset]
    add rsi, [rcx+BufferedFileReader.buffer]
    mov edx, [rbp-12]
    call memcpy

    mov rax, [rbp-24]
    mov edx, [rbp-12]
    mov byte [rax+rdx], 0

    mov rdi, [rbp-8]
    sub [rdi+BufferedFileReader.buffer_data_size], edx
    add [rdi+BufferedFileReader.buffer_offset], edx
.exit:
    mov rsp, rbp
    pop rbp

    ret

bfr_fill_buf:
    push rbp
    mov rbp, rsp

    sub rsp, 16
    mov [rbp-8], rdi ; [rbp-8]=self

    mov ecx, [rdi+BufferedFileReader.buffer_data_size]
    test ecx, ecx
    jnz .enough_data

    mov esi, [rdi+BufferedFileReader.buffer_offset]
    add esi, [rdi+BufferedFileReader.buffer_data_size]
    neg esi
    add esi, [rdi+BufferedFileReader.buffer_size]

    ; if the buffer is already full ask for 1 byte
    mov edx, 1
    test esi, esi
    cmovz esi, edx

    call bfr_try_read_more

    test eax, eax
    js .error
    jz .eof
    jmp .enough_data
.eof:
    xor rax, rax
    jmp .exit
.error:
    movsxd rax, eax
    jmp .exit
.enough_data:
    movsxd rax, eax
.exit:
    mov rsp, rbp
    pop rbp

    ret

bfr_skip:
    push rbp
    mov rbp, rsp

    sub rsp, 32
    mov [rbp-8], rdi ; [rbp-8]=self
    mov [rbp-16], rsi ; [rbp-16]=len
    mov qword [rbp-24], 0 ; [rbp-24]=char to read

    cmp rsi, BFR_MAX_BUFSIZE
    ja .einval

    mov ecx, [rdi+BufferedFileReader.buffer_data_size]
    sub ecx, esi
    jae .enough_data

    neg ecx
    add [rbp-24], rcx
.loop:
    mov esi, edx
    call bfr_try_read_more

    test eax, eax
    js .error
    jz .eof

    sub [rbp-24], rax
    jbe .enough_data
    jmp .loop
.eof:
    xor rax, rax
    jmp .exit
.error:
    movsxd rax, eax
    jmp .exit
.einval:
    mov rax, EINVAL
    jmp .exit
.enough_data:
    mov rdi, [rbp-8]
    mov rax, [rbp-16]
    add [rdi+BufferedFileReader.buffer_offset], eax
    sub [rdi+BufferedFileReader.buffer_data_size], eax
.exit:
    mov rsp, rbp
    pop rbp

    ret
