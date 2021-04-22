/* EXTERN is defined as extern except in global.c */
#ifdef	GLOBAL_VARIABLES_HERE
#undef	EXTERN
#define	EXTERN
#else
#define EXTERN extern
#endif

EXTERN	int		disp_pos;
EXTERN	unsigned char		gdt_ptr[6];	/* 0~15:Limit  16~47:Base */
EXTERN	DESCRIPTOR	gdt[GDT_SIZE];
EXTERN	unsigned char		idt_ptr[6];	/* 0~15:Limit  16~47:Base */
EXTERN	GATE		idt[IDT_SIZE];
