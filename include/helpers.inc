section .text:
    extern strrev ; (char*) -> char*
    extern int_abs ; (i32) -> i32
    extern itos ; (char* buf, u64 len, i32 val, bool is_signed) -> char*
    extern putchar ; (char)
    extern strlen ; (char*) -> u64
    extern print ; (char*)
    extern printi ; (i32)
    extern strchr ; (char*, char) -> char*
    extern memchr ; (char*, char, u64 count) -> char*
    extern memcpy ; (void* dest, void* src, u64 count)
    extern memmove ; same as memcpy but for overlapping data
    extern strcmp ; (char*, char*) -> i32


