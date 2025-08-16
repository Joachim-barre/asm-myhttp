%include "pages.inc"

section .data
    global pages

    pages: dq index, home_css, home_js, encode_post, decode_post, 0 ; Page** (page array)

    PAGE_FILE index, "GET", "/", "html/index.html" 
    PAGE_FILE home_css, "GET", "/static/home.css", "static/home.css"
    PAGE_FILE home_js, "GET", "/static/home.js", "static/home.js"

    PAGE_CALLBACK encode_post, "POST", "/encode", encode
    PAGE_CALLBACK decode_post, "POST", "/decode", decode

section .text
    extern encode
    extern decode
