struc App
    .init_callback: resq 1 ; fn() called before the http server initalialisation
    .size:
endstruc

%macro APP_DEFAULT 0
section .text
    dummy:
        ret
section .data
    global app    

    app: istruc App
        .init_callback: dq dummy
    iend
%endmacro
