BUILDDIR=build
PROG=$(BUILDDIR)/prog
OBJS=$(BUILDDIR)/main.o $(BUILDDIR)/helpers.o $(BUILDDIR)/net.o $(BUILDDIR)/thread.o $(BUILDDIR)/mem.o $(BUILDDIR)/http.o $(BUILDDIR)/pages.o
HTML_FILES=html/index.html

LD=ld
LDFLAGS=

ASM=nasm
ASMFLAGS=-f elf64 -Iinclude

all: $(PROG)
.PHONY: clean run

clean:
	rm -r $(BUILDDIR)

run: $(PROG)
	chmod +x $(PROG) && ./$(PROG)

$(BUILDDIR):
	mkdir $(BUILDDIR)

$(BUILDDIR)/%.o: src/%.asm | $(BUILDDIR)
	$(ASM) $(ASMFLAGS) $< -o $@

$(BUILDDIR)/pages.o: src/pages.asm $(HTML_FILES) | $(BUILDDIR)
	$(ASM) $(ASMFLAGS) $< -o $@

	

$(PROG): $(OBJS) | $(BUILDDIR)
	$(LD) $(LDFLAGS) $(OBJS) -o $(PROG)
