ENTRYPOINT  = 0x10000

ASM             = nasm
CC              = gcc
CFLAGS          = -m32 -g -I include/ -c -fno-builtin -fno-stack-protector
LD              = ld
ASMBFLAGS       = -I boot/include/
ASMKFLAGS       = -I lib -f elf
LDFLAGS         = -m elf_i386 -s -Ttext $(ENTRYPOINT)

ORANGESBOOT     = boot/boot.bin boot/loader.bin
ORANGESKERNEL   = kernel.bin
OBJS            = kernel/kernel.o kernel/start.o lib/string.o
BOOT_BIN        = boot/boot.bin
LDR_BIN         = boot/loader.bin
KERNEL_BIN      = kernel.bin

IMG             = boot.img
FLOPPY          = /mnt/floppy/

.PHONY : clean everything imgage all

everything: clean $(ORANGESBOOT) $(ORANGESKERNEL)
all: everything image
bochs: all bochstart

image : $(LDR_BIN) $(KERNEL_BIN)
	# bximg
	dd if=$(BOOT_BIN) of=$(IMG) bs=512 count=1 conv=notrunc
	sudo mount -o loop $(IMG) $(FLOPPY)
	sudo cp $(LDR_BIN) $(FLOPPY) -fv
	sudo cp $(KERNEL_BIN) $(FLOPPY) -fv
	sudo umount $(FLOPPY)

bochstart:
	bochs -f bochsrc.bxrc

clean :
	rm -f $(OBJS) $(ORANGESBOOT) $(ORANGESKERNEL)

$(BOOT_BIN) : boot/boot.asm boot/include/lib.asm boot/include/fat12hdr.asm
	$(ASM) $(ASMBFLAGS) -o $@ $<

$(LDR_BIN) : boot/loader.asm boot/include/lib.asm \
             boot/include/fat12hdr.asm boot/include/pm.asm
	$(ASM) $(ASMBFLAGS) -o $@ $<

$(ORANGESKERNEL) : $(OBJS)
	$(LD) $(LDFLAGS) -o $(ORANGESKERNEL) $(OBJS)

kernel/kernel.o : kernel/kernel.asm
	$(ASM) $(ASMKFLAGS) -o $@ $<

kernel/start.o : kernel/start.c kernel/start.h
	$(CC) $(CFLAGS) -o $@ $<

lib/string.o : lib/string.asm
	$(ASM) $(ASMKFLAGS) -o $@ $<
