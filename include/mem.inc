section .text
    extern heap_init
    extern malloc ; (u64 len) -> void*
    extern free ; (void*)
    extern align_up ; (u64 value, u64 align) -> u64
