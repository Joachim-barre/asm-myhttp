%include "pages.inc"

section .data
    global pages

    pages: dq index, 0 ; Page** (page array)

    PAGE_FILE index, "/", "html/index.html" 
