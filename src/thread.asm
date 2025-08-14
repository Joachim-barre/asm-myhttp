%define THREAD_SYMBOLS
%include "thread.inc"

section .data
    global thread_stack_size

    thread_stack_size equ 80 * 1024 ; 80 KiB stack

section .text
    global thread_init
    global spin_init
    global spin_lock
    global spin_unlock

spin_init: ; (SpinLock*, void*)
    push rbp
    mov rbp, rsp

    mov qword [rdi+SpinLock.lock], 0
    mov [rdi+SpinLock.ptr], rsi

    mov rsp, rbp
    pop rbp

    ret

spin_lock: ; (SpinLock*) -> void*
    push rbp
    mov rbp, rsp

.loop:
    mov rax, 0
    mov rsi, 1
    lock cmpxchg [rdi+SpinLock.lock], rsi

    jnz .loop ; ZF=0 if the cmp failed

    mov rax, [rdi+SpinLock.ptr]

    mov rsp, rbp
    pop rbp

    ret

spin_unlock: ; (SpinLock*)
    push rbp
    mov rbp, rsp

    mov qword [rdi+SpinLock.lock], 0

    mov rsp, rbp
    pop rbp

    ret

thread_init: ; (startup_fn(u64), u64 callback_arg)
    push rbp
    mov rbp, rsp

    sub rsp, 16 ; allocate stack frame
    mov [rbp-8], rdi ; [rbp-8]=startup_fn
    mov [rbp-16], rsi ; [rbp-16]=callback_arg

    ; alloc a stack
    mov rax, 9 ; sys_mmap
    mov rdi, 0 ; addr=NULL (let the os choose the address)
    mov rsi, thread_stack_size ; len
    mov rdx, 3 ; prot=PROT_READ|PROT_WRITE
    mov r10, 290 ; flags=MAP_ANONYMOUS|MAP_PRIVATE|MAP_GROWSDOWN
    mov r8, -1 ; fd=-1
    mov r9, 0 ; offset=0
    syscall

    ; save the startup function and her argument to the bottom of the thread stack
    mov rdi, [rbp-16]
    mov [rax+thread_stack_size-8], rdi
    mov rdi, [rbp-8]
    mov [rax+thread_stack_size-16], rdi

    ; create the thread
    lea rsi, [rax + thread_stack_size - 16] ; bottom of allocated stack
    mov rax, 56 ; sys_clone
    mov rdi, 2147593984 ; clone_flags=CLONE_FILES|CLONE_FS|CLONE_IO|CLONE_PARENT|CLONE_PTRACE|CLONE_SIGHAND|CLONE_THREAD|CLONE_VM
    mov rdx, 0 ; parent_tid=NULL
    mov r10, 0 ; child_tid=NULL
    mov r8, 0  ; tls=NULL
    syscall

    test rax, rax
    jz .child_handler

    mov rsp, rbp
    pop rbp

    ret ; if we are the parent return

.child_handler:
    mov rax, [rsp]
    mov rdi, [rsp+8]

    call rax ; call the child

    mov rax, 11
    lea rdi, [rsp+16-thread_stack_size] ; rax is the first page of the mapping
    mov rsi, thread_stack_size
    syscall

    mov rax, 60 ; sys_exit
    mov rdi, 0
    syscall ; exit when the child return
