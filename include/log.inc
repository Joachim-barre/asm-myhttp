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
        %elifidn %1, sp
            mov rdi, %2
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
            %warning %strcat("unknown format : ", %str(%1))
            mov dil, '?'
            call putchar
        %endif
        %rotate 2
    %endrep
%endmacro

%ifenv %!LOG_LEVEL
    %defstr LOG_LEVEL_STR, %!LOG_LEVEL
    %ifidn LOG_LEVEL_STR, "INFO"
        %define LOG_LEVEL 0
    %elifidn LOG_LEVEL_STR, "WARN"
        %define LOG_LEVEL 1
    %elifidnLOG_LEVEL_STR, "ERROR"
        %define LOG_LEVEL 2
    %elifidnLOG_LEVEL_STR, "NONE"
        %define LOG_LEVEL 3
    %else
        %warning %strcat("invalid log level : ", LOG_LEVEL_STR)
        %define LOG_LEVEL 0
        %defstr LOG_LEVEL_STR INFO
    %endif
%else
%define LOG_LEVEL_STR "INFO"
%define LOG_LEVEL 0
%endif

%macro log 4+
%if %1>=LOG_LEVEL
format is, {"[", %str(%2), "][", __?FILE?__, ":", %str(__?LINE?__), "]: "}, %3, %4
%endif
%endmacro

%macro info 2+
log 0, INFO, %1, %2
%endmacro

%macro warn 2+
log 1, WARN, %1, %2
%endmacro

%macro error 2+
log 2, ERROR, %1, %2
%endmacro
