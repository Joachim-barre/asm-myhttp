%include "thread.inc"
%include "helpers.inc"

struc BlockHeader
    .prev: resq 1
    .next: resq 1
    .len: resq 1
    .is_free: resb 1
    .pad: resb 7
    .size: 
endstruc

section .data
    alloc_error_msg: db "allocation error : ", 0

section .bss
    heap: resb SpinLock.size

section .text
    global heap_init
    global malloc
    global free

; align up to 16 byte
align_up: ; (u64 val, align) -> u64
    ; skip if alignment is i or 0
    cmp rsi, 1
    jbe .exit

    mov rdx, rsi
    sub rdx, 1 ; save the mask in rdx (align-1)

    ; skip if align isn't a power of two
    test rsi, rdx
    jnz .exit

    ; check if the value is already aligned
    test rdi, rdx
    jz .exit

    ; align the value
    or rdi, rdx
    inc rdi

.exit:
    mov rax, rdi
    ret

init_block: ; (BlockHeader* header, u64 len) -> BlockHeader*
    mov qword [rdi+BlockHeader.prev], 0
    mov qword [rdi+BlockHeader.next], 0
    mov [rdi+BlockHeader.len], rsi
    mov byte [rdi+BlockHeader.is_free], 1

    mov rax, rdi

    ret

alloc_pages: ; (void* hint, u64 size) -> BlockHeader*
    push rbp
    mov rbp, rsp

    sub rsp, 16; make room for variables
    ; [rbp-8]=size
    mov [rbp-16], rdi ; [rbp-16]=hint
    
    ; return NULL if the size is zero
    mov rax, 0
    test rsi, rsi
    jz .exit

    ; align size to the next page size
    mov rdi, rsi
    mov rsi, 4096
    call align_up

    mov [rbp-8], rsi ; save the size

    mov rax, 9 ; sys_mmap
    mov rdi, [rbp-16]; addr=hint
    ; len(rsi)=size
    mov rdx, 3 ; prot=PROT_READ|PROT_WRITE
    mov r10, 34 ; flags=MAP_ANONYMOUS|MAP_PRIVATE
    mov r8, -1 ; fd=-1
    mov r9, 0 ; offset=0
    syscall

    test rax, rax
    js .error

    ; initialize the header
    mov rdi, rax
    mov rsi, [rbp-8]
    sub rsi, BlockHeader.size
    call init_block

    ; return the adress of the header
.exit:
    mov rsp, rbp
    pop rbp

    ret

.error:
    ; print an error message and code and exit
    mov r12, rax ; save the error code into a callee saved register (do not save it's current value since we never return

    lea rdi, [alloc_error_msg]
    call print

    mov edi, r12d
    call printi

    mov dil, 10
    call putchar

    mov rax, 60 ; sys_exit
    mov rdi, r12 ; error code
    syscall


; alloc a block for a page and initialize the heap spin lock
heap_init:
    push rbp
    mov rbp, rsp

    mov rdi, 0 ; hint=NULL
    mov rsi, 4096 ; size = 4096
    call alloc_pages

    lea rdi, [heap]
    mov rsi, rax
    call spin_init

    mov rsp, rbp
    pop rbp

    ret

alloc_heap_pages: ; (BlockHeader* last, u64 min_size) -> BlockHeader*
    push rbp
    mov rbp, rsp

    sub rsp, 16 ; make room for variables
    mov [rbp-8], rdi ; [rbp-8]=last
    mov [rbp-16], rsi ; [rbp-16]=min_size

    ; compute the hint
    ; get the page after the last block
    mov rsi, [rdi+BlockHeader.len]
    lea rdi, [rdi+rsi+BlockHeader.size]
    mov rsi, 4096
    call align_up

    ; try to alloc pages next to the block
    mov rdi, rax
    mov rsi, [rbp-16]
    call alloc_pages

    ; find where to insert the block by searching the block before
    ; rax=header
    mov rdi, [rbp-8] ; i=last
.loop:
    cmp rax, rdi
    jb .found; i is the block before rax

    mov rsi, [rdi+BlockHeader.prev] ; get the previous block
    test rsi, rsi
    jz .first ; there is no block before

    mov rdi, rsi ; i=i->prev
    jmp .loop

.first:
    mov [rdi+BlockHeader.prev], rax
    mov [rax+BlockHeader.next], rax
    mov [heap+SpinLock.ptr], rax ; save this node as the first
    
    mov rsi, rdi
    mov rdi, rax
    call try_merge

    jmp .exit

.found:
    mov [rax+BlockHeader.prev], rdi
    mov rsi, [rdi+BlockHeader.next]
    mov [rax+BlockHeader.next], rsi
    test rsi, rsi
    jz .no_next
    mov [rsi+BlockHeader.prev], rax

.no_next:
    mov [rdi+BlockHeader.next], rax

    ; rdi is already the correct value
    mov rsi, rax
    call try_merge

    jmp .exit

.exit:
    mov rsp, rbp
    pop rbp

    ret

; if the block can merge:
; modify the data of the first node and remove the second
; always returns a pointer to the first block
try_merge: ; (BlockHeader* first, BlockHeader* second) -> BlockHeader*
    push rbp
    mov rbp, rsp

    ; check if the two blocks are free and exit if not
    mov rax, rdi ; put the first block in rax since it is the register used for returned values
    mov dil, [rax+BlockHeader.is_free]
    test dil, dil
    jz .exit

    mov dil, [rsi+BlockHeader.is_free]
    test dil, dil
    jz .exit

    ; check if the block are continuous
    mov rdi, [rax+BlockHeader.len]
    add rdi, BlockHeader.size
    cmp rdi, rsi
    jne .exit

    ; the two blocks can merge
    
    ; add the size of the second block to the first
    mov rdi, [rsi+BlockHeader.len]
    add rdi, BlockHeader.size
    add [rax+BlockHeader.len], rdi

    ; update the next block
    mov rdi, [rsi+BlockHeader.next]
    mov [rax+BlockHeader.next], rdi

    ; if there is a next block update it's previous node
    test rdi, rdi
    jz .no_next

    mov [rdi+BlockHeader.prev], rax

.no_next:

.exit:
    mov rsp, rbp
    pop rbp

    ret


; split a block into two blocks
; the first return ptr is always the one passed as first argument
; the second is the second split block if the split what possible and NULL otherwise
try_split_block: ; (BlockHeader*, u64 len) -> (BlockHeader*, BlockHeader*)
    push rbp
    mov rbp, rsp

    sub rsp, 16 ; make room for local variable
    mov [rbp-8], rdi ; [rbp-8]=first_block
    
    ; round the lenght to the next multible of 16
    mov rdi, rsi
    mov rsi, 16
    call align_up

    mov rdi, [rbp-8]
    mov rsi, rax

    ; check if the block is big enough to be split 
    mov rax, rdi ; save the first block to rax since it is the first return register
    mov rdx, 0 ; initialize the second return register to NULL
    mov rdi, [rax+BlockHeader.len]
    lea rcx, [rsi+ BlockHeader.size + 16]
    cmp rdi, rcx ; split only if the second block can store at least 16 bytes of data
    jb .exit

    ; the block can be split up

    ; set the lenght of the first block and save the old lenght in rdx
    mov rdx, rsi
    xchg [rax+BlockHeader.len], rdx
    
    ; initialize the second block
    lea rdi, [rax+rsi+BlockHeader.size] ; second_block=first_block+first_block->len+sizeof(BlockHeader)
    lea rsi, [rdx-BlockHeader.size+rsi] ; len=old_len-sizeof(BlockHeader)-new_len
    call init_block

    ; put the first_block in rax and the second in rdx
    mov rdx, rax
    mov rax, [rbp-8]

    ; set second_block->is_free to first_block->is_free
    mov dil, [rax+BlockHeader.is_free]
    mov [rdx+BlockHeader.is_free], dil

    ; update links
    mov [rdx+BlockHeader.prev], rax
    mov rdi, [rax+BlockHeader.next]
    mov [rdx+BlockHeader.next], rdi
    mov [rax+BlockHeader.next], rdx
    
    ; if the first_block had a next block update it too
    test rdi, rdi
    jz .no_next

    mov [rdi+BlockHeader.prev], rdx

.no_next:

.exit:
    mov rsp, rbp
    pop rbp

    ret

malloc: 
    push  rbp
    mov rbp, rsp

    ; if len==0 return NULL
    mov rax, 0
    test rdi, rdi
    jz .exit_no_lock

    sub rsp, 16 ; make room for local variables
    mov [rbp-8], rdi ; [rbp-8]=len

    lea rdi, [heap]
    call spin_lock

    ; rax: i=first_block
    mov rdi, [rbp-8] ; rdi=len
.loop:
    mov dl, [rax+BlockHeader.is_free]
    test dl, dl
    jz .go_next

    mov rdx, [rax+BlockHeader.len]
    cmp rdx, rdi
    jb .go_next

    jmp .found_block

.go_next:
    mov rdx, [rax+BlockHeader.next]
    test rdx, rdx
    jz .no_next

    mov rax, rdx ;  i=i->next
    jmp .loop

.no_next:
    mov rsi, rdi
    mov rdi, rax
    call alloc_heap_pages

    jmp .found_block

.found_block:
    ; try to split the block and ignore the second
    mov rdi, rax
    mov rsi, [rbp-8]
    call try_split_block

    ; mark the block as not free
    mov byte [rax+BlockHeader.is_free], 0

    ; offset the pointer by the size of the Header
    add rax, BlockHeader.size

.exit:
    lea rdi, [heap]
    call spin_unlock

.exit_no_lock:
    mov rsp, rbp
    pop rbp

    ret

free: ; (void*)
    push rbp
    mov rbp, rsp

    ; get the address of the header
    sub rdi, BlockHeader.size

    sub rsp, 16
    mov [rbp-8], rdi ; [rbp-8]=header

    ; lock the heap
    lea rdi, [heap]
    call spin_lock

    ; mark the block as free
    mov rdi, [rbp-8]
    mov byte [rdi+BlockHeader.is_free], 1
    
    ; try to merge this block with the next one
    mov rsi, [rdi+BlockHeader.next]
    call try_merge

    ; try to merge it with the previous one
    mov rsi, [rbp-8]
    mov rdi, [rsi+BlockHeader.prev]
    call try_merge

.exit:
    lea rdi, [heap]
    call spin_unlock

    mov rsp, rbp
    pop rbp

    ret

