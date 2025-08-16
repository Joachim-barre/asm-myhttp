%include "pages.inc"

section .data
    global pages

    pages: dq index, index_css, 0 ; Page** (page array)

    PAGE_FILE index, "/", "html/index.html" 
    PAGE_FILE index_css, "/static/index.css", "static/index.css"
