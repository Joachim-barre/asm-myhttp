section .text
    extern heap_init
    extern malloc ; (u64 len) -> void*
    extern free ; (void*)
