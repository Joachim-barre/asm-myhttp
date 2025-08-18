%define LINKEDLIST_SYMBOLS
%include "linkedlist.inc"
%include "mem.inc"
%include "helpers.inc"

section .text
    global ll_init
    global ll_clear
    global ll_push_front
    global ll_push_back
    global ll_front
    global ll_back
    global ll_is_empty
    global ll_len
    global ll_pop_front
    global ll_pop_back
    global ll_iter
    global ll_iter_next

ll_init:
    mov [rdi+LinkedList.item_size], rsi
    mov qword [rdi+LinkedList.front_node], 0
    mov qword [rdi+LinkedList.back_node], 0

    ret

ll_clear:
    push rbp
    mov rbp, rsp

    sub rsp, 16
    mov [rbp-8], rdi ; [rbp-8]=list
    mov rsi, [rdi+LinkedList.front_node]
    mov [rbp-16], rsi ; [rbp-16]=current
.loop:
    mov rdi, [rbp-16]
    test rdi, rdi
    jz .loop_end
    mov rsi, [rdi+LLNodeHeader.next]
    mov [rbp-16], rsi

    call free

    jmp .loop

.loop_end:
    mov rdi, [rbp-8]
    mov qword [rdi+LinkedList.front_node], 0
    mov qword [rdi+LinkedList.back_node], 0

    mov rsp, rbp
    pop rbp

    ret


ll_alloc_node: ; (LinkedList*) -> LLNode*
    push rbp
    mov rbp, rsp

    mov rdi, [rdi+LinkedList.item_size]
    add rdi, LLNodeHeader.size
    call malloc

    mov qword [rax+LLNodeHeader.next], 0
    mov qword [rax+LLNodeHeader.prev], 0

    mov rsp, rbp
    pop rbp

    ret

ll_push_front:
    push rbp
    mov rbp, rsp

    sub rsp, 16
    mov [rbp-8], rdi ; [rbp-8]=list
    mov [rbp-16], rsi ; [rbp-16]=item

    call ll_alloc_node

    mov rdi, [rbp-8]
    mov rsi, [rdi+LinkedList.front_node]
    
    mov [rax+LLNodeHeader.next], rsi
    mov [rdi+LinkedList.front_node], rax

    test rsi, rsi
    jz .empty

    mov [rsi+LLNodeHeader.prev], rax

    jmp .inserted
.empty:
    mov [rdi+LinkedList.back_node], rax  

.inserted:
    mov rdx, [rdi+LinkedList.item_size]
    lea rdi, [rax+LLNodeHeader.size]
    mov rsi, [rbp-16]
    call memcpy

    mov rsp, rbp
    pop rbp

    ret

ll_push_back:
    push rbp
    mov rbp, rsp

    sub rsp, 16
    mov [rbp-8], rdi ; [rbp-8]=list
    mov [rbp-16], rsi ; [rbp-16]=item

    call ll_alloc_node

    mov rdi, [rbp-8]
    mov rsi, [rdi+LinkedList.back_node]
    
    mov [rax+LLNodeHeader.prev], rsi
    mov [rdi+LinkedList.back_node], rax

    test rsi, rsi
    jz .empty

    mov [rsi+LLNodeHeader.next], rax

    jmp .inserted
.empty:
    mov [rdi+LinkedList.front_node], rax  

.inserted:
    mov rdx, [rdi+LinkedList.item_size]
    lea rdi, [rax+LLNodeHeader.size]
    mov rsi, [rbp-16]
    call memcpy

    mov rsp, rbp
    pop rbp

    ret

ll_front:
    mov rax, [rdi+LinkedList.front_node]
    add rax, LLNodeHeader.size
     
    ret

ll_back:
    mov rax, [rdi+LinkedList.back_node]
    add rax, LLNodeHeader.size
     
    ret

ll_is_empty:
    mov rax, [rdi+LinkedList.front_node]
    test rax, rax
    jz .empty

    mov eax, 1
    ret

.empty:
    xor eax, eax
    ret

ll_len:
    mov rsi, [rdi+LinkedList.front_node]
    xor rax, rax

.loop:
    test rsi, rsi
    jz .exit
    mov rsi, [rsi+LLNodeHeader.next]
    
    inc rax

    jmp .loop

.exit:
    ret

ll_pop_front:
    push rbp
    mov rbp, rsp

    mov rsi, [rdi+LinkedList.front_node]
    mov rdx, [rsi+LLNodeHeader.next]
    mov [rdi+LinkedList.front_node], rdx

    test rdx, rdx
    jnz .not_empty

    mov qword [rdi+LinkedList.back_node], 0

.not_empty:
    mov rdi, rsi
    call free

    mov rsp, rbp
    pop rbp

    ret

ll_pop_back:
    push rbp
    mov rbp, rsp

    mov rsi, [rdi+LinkedList.back_node]
    mov rdx, [rsi+LLNodeHeader.prev]
    mov [rdi+LinkedList.back_node], rdx

    test rdx, rdx
    jnz .not_empty

    mov qword [rdi+LinkedList.front_node], 0

.not_empty:
    mov rdi, rsi
    call free

    mov rsp, rbp
    pop rbp

    ret

ll_iter:
    mov rax, [rdi+LinkedList.front_node]
    ret

ll_iter_next:
    test rdi, rdi
    jz .end

    mov rax, [rdi+LLNodeHeader.next]
    
    lea rdx, [rdi+LLNodeHeader.size]
    
    ret

.end:
    mov rax, 0
    xor rdx, rdx

    ret
