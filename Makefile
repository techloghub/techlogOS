ENTRYPOINT  = 0x10000

ASM             = nasm
CC              = gcc
CFLAGS          = -m32 -g -I include/ -c -fno-builtin -fno-stack-protector
LD              = ld
ASMBFLAGS       = -I boot/inc/
ASMKFLAGS       = -I lib -f elf
LDFLAGS         = -m elf_i386 -s -Ttext $(ENTRYPOINT)

OBJS            = kernel/kernel.o kernel/protect.o lib/extern.o kernel/i8259.o lib/functions.o kernel/global.o
BOOT_BIN        = boot/boot.bin
LOADER_BIN      = boot/loader.bin
KERNEL_BIN      = kernel/kernel.bin

IMG             = boot.img
FLOPPY          = /mnt/floppy/

.PHONY : clean everything imgage all bochs

everything: clean $(BOOT_BIN) $(LOADER_BIN) $(KERNEL_BIN)
all: everything image
bochs: all clean bochstart

image : $(LOADER_BIN) $(KERNEL_BIN)
	# bximg
	dd if=$(BOOT_BIN) of=$(IMG) bs=512 count=1 conv=notrunc
	sudo mount -o loop $(IMG) $(FLOPPY)
	sudo cp $(LOADER_BIN) $(FLOPPY) -fv
	sudo cp $(KERNEL_BIN) $(FLOPPY) -fv
	sudo umount $(FLOPPY)

bochstart:
	bochs -f bochsrc.bxrc

clean :
	rm -f $(OBJS) $(BOOT_BIN) $(LOADER_BIN) $(KERNEL_BIN)

$(BOOT_BIN) : boot/boot.asm boot/inc/lib.asm boot/inc/fat12hdr.asm
	$(ASM) $(ASMBFLAGS) -o $@ $<

$(LOADER_BIN) : boot/loader.asm boot/inc/lib.asm \
             boot/inc/fat12hdr.asm boot/inc/pm.asm
	$(ASM) $(ASMBFLAGS) -o $@ $<

$(KERNEL_BIN) : $(OBJS)
	$(LD) $(LDFLAGS) -o $(KERNEL_BIN) $(OBJS)

kernel/kernel.o : kernel/kernel.asm
	$(ASM) $(ASMKFLAGS) -o $@ $<

kernel/protect.o : kernel/protect.c kernel/protect.h kernel/i8259.h
	$(CC) $(CFLAGS) -o $@ $<

lib/extern.o : lib/extern.asm
	$(ASM) $(ASMKFLAGS) -o $@ $<

kernel/i8259.o : kernel/i8259.c kernel/i8259.h
	$(CC) $(CFLAGS) -o $@ $<

lib/functions.o : lib/functions.c
	$(CC) $(CFLAGS) -o $@ $<

kernel/global.o : kernel/global.c
	$(CC) $(CFLAGS) -o $@ $<
