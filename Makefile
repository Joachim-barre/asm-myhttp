BUILDDIR=build
PROG=$(BUILDDIR)/prog
OBJS=$(BUILDDIR)/main.o $(BUILDDIR)/helpers.o $(BUILDDIR)/net.o $(BUILDDIR)/thread.o

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

$(PROG): $(OBJS) | $(BUILDDIR)
	$(LD) $(LDFLAGS) $(OBJS) -o $(PROG)
