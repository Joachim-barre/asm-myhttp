%include "pages.inc"

section .data
    global pages

    pages: dq index, index_css, 0 ; Page** (page array)

    PAGE_FILE index, "GET", "/", "html/index.html" 
    PAGE_FILE index_css, "GET", "/static/index.css", "static/index.css"
