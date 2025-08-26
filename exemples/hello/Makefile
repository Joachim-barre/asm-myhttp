LIB_DIR=../..
LIB_BUILD=$(LIB_DIR)/build
LIB=$(LIB_BUILD)/libmyhttp.a
BUILDDIR=build
PROG=$(BUILDDIR)/prog
OBJS=$(BUILDDIR)/main.o $(BUILDDIR)/pages.o
PAGES=html/index.html static/index.css

LD=ld
LDFLAGS=

ASM=nasm
ASMFLAGS=-f elf64 -I$(LIB_DIR)/include

all: $(PROG)
.PHONY: clean run $(LIB)

clean:
	rm -r $(BUILDDIR)

run: $(PROG)
	chmod +x $(PROG) && ./$(PROG) $(ARGS)

$(BUILDDIR):
	mkdir $(BUILDDIR)

$(BUILDDIR)/%.o: src/%.asm | $(BUILDDIR)
	$(ASM) $(ASMFLAGS) $< -o $@

$(BUILDDIR)/pages.o: src/pages.asm $(PAGES) | $(BUILDDIR)
	$(ASM) $(ASMFLAGS) $< -o $@

$(PROG): $(OBJS) $(LIB) | $(BUILDDIR)
	$(LD) $(LDFLAGS) -L$(LIB_BUILD) -lmyhttp $(OBJS) -o $(PROG)

$(LIB):
	make -C $(LIB_DIR)
