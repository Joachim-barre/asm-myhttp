section .data
    global content_lenght
    global connection
    global connection_keep_alive
    global connection_close

    content_lenght: db "Content-Length", 0
    connection: db "Connection", 0
    connection_keep_alive: db "keep-alive", 0
    connection_close: db "close", 0
