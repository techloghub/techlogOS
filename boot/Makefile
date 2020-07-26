# Makefile for boot

# Programs, flags, etc.
ASM		= nasm
ASMFLAGS	= -I include/

# This Program
TARGET		= boot.bin loader.bin

# All Phony Targets
.PHONY : everything clean all

# Default starting position
everything : $(TARGET)

clean :
	rm -f $(TARGET)

all : clean everything

boot.bin : boot.asm include/fat12hdr.asm include/lib.asm
	$(ASM) $(ASMFLAGS) -o $@ $<

loader.bin : loader.asm include/lib.asm include/fat12hdr.asm include/pm.asm
	$(ASM) $(ASMFLAGS) -o $@ $<

