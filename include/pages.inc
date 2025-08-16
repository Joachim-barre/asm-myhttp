struc Page
    .path: resq 1 ; char *
    .data: resq 1 ; char *
endstruc

%ifndef PAGES_SYMBOLS
section .text
    extern find_page
%endif
