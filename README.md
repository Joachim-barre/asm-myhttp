# My simple http 1.1 asm webserver

this project is a simple (pretty unstable) webserver written in x64 assembly that targets linux, and doesn't depend on anything other than the kernel's system calls at runtime

the project is design so that the compiled program can run by itself and doesn't depend on any other file<br>
the exemple each compile to the following sizes:
|path|description|size before ```strip```|size after ```strip```|
|--|--|--|
| ```exemples/hello``` |as simple webpage with a css file| 36K | 16K |
| ```exemples/emojify``` |a port of my [other project]()| 40K | 20K |
| ```exemples/simple_chat``` | 40K | 20K |


## building the project

to build the project you need : ```gnu make```, ```nasm```, ```gnu ar``` and ```gnu ld```

to build any exemple or the library just run ```make```

## using the project

to the use this project, I recommand using ```exemple/hello``` as a template by simply modifying the LIB_DIR variable on top of the make file<br>
the api for the project is either documented in the ".inc" file or in the ".asm" file
