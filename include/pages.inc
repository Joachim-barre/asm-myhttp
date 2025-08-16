struc Page
    .path: resq 1 ; char *
    ; kind specifiy what data is
    ; 0: data0 is a char* which has a len that can be computed with strlen, data1 is ignored
    ; 1: data0 is a char* raw binary data, data1 is it's length
    ; 2: data0 is a pointer to a funcion with the signature : fn(HttpRequest*, int fd), data1 is ignored
    .kind: resq 1
    .data0: resq 1 ; void *
    .data1: resq 1 ; depends on kind
endstruc

; (name, http_path, file_path)
%macro PAGE_FILE 3
    %1: istruc Page 
        at Page.path, dq .path
        at Page.kind, dq 0
        at Page.data0, dq .data
    iend
    .path: db %2, 0
    .data: incbin %3
    db 0
%endmacro

%ifndef PAGES_SYMBOLS
section .text
    extern find_page
%endif
