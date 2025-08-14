section .text
    global strrev
    global int_abs
    global itoa
    global putchar
    global strlen
    global print
    global printi
    global find_char
    global memcpy

strrev: 
	push rbp
	mov rbp, rsp
	sub rsp, 32

	mov [rbp-8], rdi
	mov [rbp-24], rdi

	call strlen
	mov rdi, [rbp-8]
	lea rax, [rax-1+rdi]
	mov [rbp-16], rax

.loop:
	mov rdi, [rbp-8]
	cmp rdi, [rbp-16]
	jge .exit

	mov rdi, [rbp-8]
	mov rsi, [rbp-16]
	
	mov dl, [rdi]
	mov cl, [rsi]

	mov [rdi], cl
	mov [rsi], dl

	inc qword [rbp-8]
	dec qword [rbp-16]

	jmp .loop

.exit:
	mov rax, [rbp-24]

	mov rsp, rbp
	pop rbp

	ret

int_abs:
	mov eax, edi
	sar edi, 31
	xor eax, edi
	sub eax, edi
	ret

itos: ;(char* buf, size_t lenght, int value, bool signed) -> char*
	push rbp
	mov rbp, rsp
	sub rsp, 32

	mov [rbp-8], rdi
	mov [rbp-16], rsi
	mov [rbp-20], edx
	mov [rbp-24], ecx
	mov qword [rbp-32], 0

	cmp rsi, 2
	jl .err

	test ecx, ecx
	jz .L0

	test edx, edx
	jns .L0

	mov byte [rdi], '-'

	inc qword [rbp-32]

	cmp rsi, 3
	jl .err

	mov rdi, [rbp-20]
	call int_abs
	mov [rbp-20], rax

.L0:
	mov edi, [rbp-20]
	test edi, edi
	jnz .loop

	mov rdi, [rbp-8]
	mov rdx, [rbp-32]
	mov byte [rdi+rdx], '0'

	inc qword [rbp-32]

	jmp .ok

.loop:
	xor edx, edx
	mov eax, [rbp-20]
	mov edi, 10
	div edi

	mov [rbp-20], eax

	add dl, '0'
	mov rdi, [rbp-8]
	mov rsi, [rbp-32]
	mov [rdi+rsi], dl

	inc qword [rbp-32]

	test eax, eax
	jz .ok

	mov rdi, [rbp-32]
	sub rdi, [rbp-16]
	cmp rdi, -2
	jg .err

	jmp .loop

.ok:
	mov rdi, [rbp-8]
	mov rdx, [rbp-32]
	mov byte [rdi+rdx], 0

	lea rdx, [rdi+1]
	cmp byte [rdi], '-'
	cmove rdi, rdx
	
	call strrev
	mov [rbp-8], rax

	jmp .exit

.err:
	mov qword [rbp-8], 0
	jmp .exit
.exit:
	mov rax, [rbp-8]

	mov rsp, rbp
	pop rbp

	ret
	

putchar:
	push rbp
	mov rbp, rsp
	sub rsp, 16

	mov [rbp-1], dil

	mov rax, 1
	mov rdi, 1
	lea rsi, [rbp-1]
	mov rdx, 1
	syscall

	mov rsp, rbp
	pop rbp

	ret

strlen:
	push rbp
	mov rbp, rsp
	sub rsp, 8
	mov [rbp-8], rdi
	
	xor ecx, ecx
	not ecx
	mov al, 0
	repne scasb

	sub rdi, [rbp-8]
	lea rax, [rdi-1]

	mov rsp, rbp
	pop rbp

	ret

print:
	push rbp
	mov rbp, rsp
	sub rsp, 16
	
	mov [rbp-8], rdi

	call strlen

	mov [rbp-16], rax

	mov rax, 1
	mov rdi, 1
	mov rsi, [rbp-8]
	mov rdx, [rbp-16]
	syscall

	mov rsp, rbp
	pop rbp

	ret

printi:
	push rbp
	mov rbp, rsp
	sub rsp, 16

	mov edx, edi
	mov ecx, esi
	lea rdi, [rbp-16]
	mov rsi, 16
	call itos

	mov rdi, rax
	call print

	mov rsp, rbp
	pop rbp
	ret

find_char: ; (char*, u64 len, char) -> u64
	push rbp
	mov rbp, rsp
	sub rsp, 8
	mov [rbp-8], rdi
	
	mov rcx, rsi
	mov al, dl
	repne scasb

	sub rdi, [rbp-8]
	lea rax, [rdi-1]

	mov rsp, rbp
	pop rbp

	ret

memcpy: ; (void*, void*, count)
    mov rcx, rdx
    rep movsq

    ret
