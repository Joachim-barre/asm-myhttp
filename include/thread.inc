struc SpinLock
    .lock: resq 1 
    .ptr: resq 1
    .size:
endstruc

%ifndef THREAD_SYMBOLS
section .text
    extern thread_init
    extern spin_init
    extern spin_lock
    extern spin_unlock

section .data
    extern thread_stack_size
%endif
