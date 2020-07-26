SELECTOR_KERNEL_CS	equ	8

; 导入函数与全局变量
extern  copy_gdt	
extern	gdt_ptr

[SECTION .bss]
StackSpace		resb	2 * 1024 * 1024
StackTop:

[section .text]
global _start

_start:
	mov	esp, StackTop	; 堆栈在 bss 段中

	sgdt	[gdt_ptr]	; cstart() 中将会用到 gdt_ptr
	call	copy_gdt	; 在此函数中改变了gdt_ptr，让它指向新的GDT
	lgdt	[gdt_ptr]	; 使用新的GDT

	jmp	SELECTOR_KERNEL_CS:csinit
csinit:                 ; 长跳转，让 GDT 切换生效

	push	0
	popfd

	hlt
