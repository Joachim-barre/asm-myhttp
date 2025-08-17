struc LinkedList
    .item_size: resq 1
    .front_node: resq 1
    .back_node: resq 1
    .size:
endstruc

struc LLNodeHeader
    .next: resq 1
    .prev: resq 1
    .size:
endstruc

%ifndef LINKEDLIST_SYMBOLS
section .text
    extern ll_init ; (LinkedList*, u64 item_size)
    extern ll_clear ; (LinkedList*)
    extern ll_push_front ; (LinkedList*, void* item) -> void*
    extern ll_push_back ; (LinkedList*, void* item) -> void*
    extern ll_front ; (LinkedList*) -> void*
    extern ll_back ; (LinkedList*) -> void*
    extern ll_is_empty ; (LinkedList*) -> bool
    extern ll_len ; (LinkedList*) -> u64
    extern ll_pop_front ; (LinkedList*)
    extern ll_pop_back ; (LinkedList*)
    extern ll_iter ; (LinkedList*) -> LinkedListIter*
    extern ll_iter_next ; (LinkedListIter*) -> (LinkedListIter*, void*)
%endif
