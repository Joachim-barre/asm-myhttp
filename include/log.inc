; from the write file macro in nasm docs
; print the string passed as argument
; exemple usage: print_inline "Hello World!", 10
%macro print_inline 1+
    [section .data]

%%str: db %1 , 0

    __?SECT?__

    lea rdi, [%%str]
    call print
%endmacro

%macro format_ip 2
    mov edi, %1
    mov si, %2
    call print_ip_port
%endmacro

%macro format 2-*
    %rep %0/2
        %ifidn %1, s
            lea rdi, [%2]
            call print
        %elifidn %1, is
            print_inline %2
        %elifidn %1, i
            %ifnum %2
                print_inline %str(%2)
            %else
                mov edi, %2
                call printi
            %endif
        %elifidn %1, c
            mov dil, %2
            call putchar
        %elifidn %1, ip
            format_ip %2 
        %elifidn %1, nop
        %else
            mov dil, '?'
            call putchar
        %endif
        %rotate 2
    %endrep
%endmacro

%macro log 3+
format is, {"[", %str(%1), "]: "}, %2, %3
%endmacro

%macro info 2+
log INFO, %1, %2
%endmacro

%macro warn 2+
log WARN, %1, %2
%endmacro

%macro error 2+
log ERROR, %1, %2
%endmacro
