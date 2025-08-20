; TODO: BufferedFileWriter for http_send_responce

%define BFR_INITIAL_BUFSIZE 1024
%define BFR_MAX_BUFSIZE 1<<24

struc BufferedFileReader
    .buffer: resq 1
    .buffer_size: resd 1 ; since it cannot exceed 2MiB
    .buffer_offset: resd 1 ; the offset the reader is at in the buffer
    .buffer_data_size: resd 1; the size of data read during the last system call
    .fd: resd 1 ; the file descriptor
    .size: ; should stay 24
endstruc

%define EINVAL -22
%define EFBIG -27

%ifndef IO_SYMBOLS
section .text
    extern bfr_init ; (BufferedFileReader*, u32 fd)
    ; free the buffer but does not close the file
    extern bfr_free ; (BufferedFileReader*)
    ; close the file and free the buffer
    ; returns a negative value on error
    extern bfr_close ; (BufferedFileReader*) -> i32
    
    ; for the following methods on BufferedFileReader
    ; - if len exceeds BFR_MAX_BUFSIZE (2MiB) EINVAL is returned
    ; - on error, they will return the error code as a negative number
    ; - on eof, the reader will return null

    ; try to read some character to the buffer if the buffer is empty
    ; on success return the quantity of character currently in the buffer
    ; return 0 on eof and a negative value or error
    extern bfr_fill_buf

    ; if read returns less than the lenght read will not retry
    ; returns the number of char that where read
    extern bfr_read ; (BufferedFileReader*, char* buf, u64 len) -> u64
    ; will retry until the full lenght is read or eof
    ; returns the number of chars that where read, it should always be equal to len except on eof
    extern bfr_read_all ; (BufferedFileReader*, char* buf, u64 len) -> u64
    
    ; if eof is reached before the char has been found null will be returned and no character will be consumed
    ; if the the size needed to reach the character is bigger than BFR_MAX_BUFSIZE, then EFBIG is returned
    ; the returned buffer should be freed by the user and is always null terminated
    extern bfr_read_until ; (BufferedFileReader*, char) -> (char*, u64)
%endif
