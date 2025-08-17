struc Page
    .path: resq 1 ; char *
    .method: resq 1 ; char *
    ; kind specifiy what data is
    ; 0: data0 is a char* which has a len that can be computed with strlen, data1 is ignored
    ; 1: data0 is a char* raw binary data, data1 is it's length
    ; 2: data0 is a pointer to a funcion with the signature : fn(HttpRequest*, int fd) -> bool, data1 is ignored and the return value is used to determine if the connection should be kept alive
    .kind: resq 1
    .data0: resq 1 ; void *
    .data1: resq 1 ; depends on kind
endstruc

; (name, method, http_path, file_path)
%macro PAGE_FILE 4
    %1: istruc Page 
        at Page.path, dq .path
        at Page.method, dq .method
        at Page.kind, dq 0
        at Page.data0, dq .data
    iend
    .method: db %2, 0
    .path: db %3, 0
    .data: incbin %4
    db 0
%endmacro

; (name, method, http_path, file_path)
%macro PAGE_FILE_BIN 4
    %1: istruc Page 
        at Page.path, dq .path
        at Page.method, dq .method
        at Page.kind, dq 1
        at Page.data0, dq .data
        at Page.data1, dq .len
    iend
    .method: db %2, 0
    .path: db %3, 0
    .data: incbin %4
    .len equ $- .data
%endmacro

; (name, method, http_path, function)
%macro PAGE_CALLBACK 4
    %1: istruc Page 
        at Page.path, dq .path
        at Page.method, dq .method
        at Page.kind, dq 2
        at Page.data0, dq %4
    iend
    .method: db %2, 0
    .path: db %3, 0
%endmacro

%ifndef PAGES_SYMBOLS
section .text
    extern find_page
%endif
