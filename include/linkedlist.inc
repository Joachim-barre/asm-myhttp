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

; (name, item_size, front_node, back_node)
%macro LL_STATIC 4
    %1: istruc LinkedList
        at LinkedList.item_size, dq %2
        at LinkedList.front_node, dq %3
        at LinkedList.back_node, dq %4
    iend
%endmacro

; (name, data, next, prev)
; if you want you can pass nothing into the data argument and specify the data as the next line
%macro LL_STATIC_NODE 4
    %1: istruc LLNodeHeader
        at LLNodeHeader.next, dq %3
        at LLNodeHeader.prev, dq %4
    iend
    %2
%endmacro

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
    ; find an item in the list
    ; use the second argument to compare the value by passing the third argument and the current item to it
    ; returns null if not found
    extern ll_find ; (LinkedList*, fn(void*, void*) -> bool, void*) -> void*
%endif
