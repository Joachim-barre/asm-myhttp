BUILDDIR=build
LIB=$(BUILDDIR)/libmyhttp.a
OBJS=$(BUILDDIR)/main.o $(BUILDDIR)/helpers.o $(BUILDDIR)/net.o $(BUILDDIR)/thread.o $(BUILDDIR)/mem.o $(BUILDDIR)/http.o $(BUILDDIR)/pages.o $(BUILDDIR)/linkedlist.o

AR=ar
ARFLAGS=

ASM=nasm
ASMFLAGS=-f elf64 -Iinclude

all: $(LIB)
.PHONY: clean

clean:
	rm -r $(BUILDDIR)

$(BUILDDIR):
	mkdir $(BUILDDIR)

$(BUILDDIR)/%.o: src/%.asm | $(BUILDDIR)
	$(ASM) $(ASMFLAGS) $< -o $@

$(LIB): $(OBJS) | $(BUILDDIR)
	$(AR) $(ARFLAGS) rcs $(LIB) $(OBJS)

TODO: build file for exemple/hello
