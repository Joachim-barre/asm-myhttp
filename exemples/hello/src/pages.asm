%include "pages.inc"

section .data
    global pages

    pages: dq index, 0 ; Page** (page array)

    index: istruc Page
        at Page.path, dq index_path
        at Page.kind, dq 0
        at Page.data0, dq index_data
    iend

    index_path: db "/", 0
    index_data: incbin "html/index.html" db 0
