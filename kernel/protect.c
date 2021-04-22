#include "protect.h"
#include "functions.h"
#include "i8259.h"

void init_protect_mode() {
    clear_screen();
	print("----- welcome to the kernel by techlog.cn -----\n\n");

	/* gdt_ptr[6] 共 6 个字节：0~15:Limit  16~47:Base。用作 sgdt/lgdt 的参数。*/
	unsigned short* p_gdt_limit = (unsigned short*)(&gdt_ptr[0]);
	unsigned int* p_gdt_base  = (unsigned int*)(&gdt_ptr[2]);

	/* 将 LOADER 中的 GDT 复制到新的 GDT 中 */
	memcpy(&gdt, (void*)(*p_gdt_base), *p_gdt_limit + 1);

	*p_gdt_limit = GDT_SIZE * sizeof(DESCRIPTOR) - 1;
	*p_gdt_base  = (unsigned int)&gdt;

	print("----- finish initialization of gdt -----\n\n");

	/* idt_ptr[6] 共 6 个字节：0~15:Limit  16~47:Base。用作 sidt/lidt 的参数。*/
	unsigned short* p_idt_limit = (unsigned short*)(&idt_ptr[0]);
	unsigned int* p_idt_base  = (unsigned int*)(&idt_ptr[2]);
	*p_idt_limit = IDT_SIZE * sizeof(GATE) - 1;
	*p_idt_base  = (unsigned int)&idt;

    init_prot();

	print("----- finish initialization of idt -----\n");
}

