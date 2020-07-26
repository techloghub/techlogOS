#include "start.h"

unsigned char gdt_ptr[6];	/* 0~15:Limit  16~47:Base */
DESCRIPTOR gdt[GDT_SIZE];
extern int disp_pos;

void copy_gdt()
{
    clear_screen();
	disp_str("----- welcome to the kernel by techlog.cn -----\0");
	disp_str("\n----- start to copy gdt ... -----\0");
	disp_str("\n----- copy gdt ends -----\0");

	/* gdt_ptr[6] 共 6 个字节：0~15:Limit  16~47:Base。用作 sgdt/lgdt 的参数。*/
	unsigned short* p_gdt_limit = (unsigned short*)(&gdt_ptr[0]);
	unsigned int* p_gdt_base  = (unsigned int*)(&gdt_ptr[2]);

	/* 将 LOADER 中的 GDT 复制到新的 GDT 中 */
	memcpy(&gdt, (void*)(*p_gdt_base), *p_gdt_limit + 1);

	*p_gdt_limit = GDT_SIZE * sizeof(DESCRIPTOR) - 1;
	*p_gdt_base  = (unsigned int)&gdt;

	disp_str("\n----- copy gdt ends -----\0");
}

void clear_screen() {
    char blank[50], i;
    for (i = 0; i < 50; ++i) {
        if (i == 48) {
            blank[i] = '\n';
            blank[i + 1] = '\0';
            break;
        } else {
            blank[i] = ' ';
        }
    }
    for (i = 0; i < 80; ++i) {
        disp_str(blank);
    }
    disp_pos = 0;
}

