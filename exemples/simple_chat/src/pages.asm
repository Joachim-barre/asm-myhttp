%include "pages.inc"

section .data
    global pages

    pages: dq index, index_css, index_js, 0 ; Page** (page array)

    PAGE_FILE index, "GET", "/", "html/index.html" 
    PAGE_FILE index_css, "GET", "/static/index.css", "static/index.css"
    PAGE_FILE index_js, "GET", "/static/index.js", "static/index.js"

    PAGE_CALLBACK events, "GET", "/events", events_callback

section .text
    extern events_callback
