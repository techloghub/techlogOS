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

#ifndef _TECHLOGOS_PROTECT_H_
#define _TECHLOGOS_PROTECT_H_

/* GDT 中描述符的个数 */
#define GDT_SIZE 128
/* IDT 中描述符的个数 */
#define	IDT_SIZE 256

/* 系统段描述符类型值说明 */
#define	DA_LDT			0x82	/* 局部描述符表段类型值			*/
#define	DA_TaskGate		0x85	/* 任务门类型值				*/
#define	DA_386TSS		0x89	/* 可用 386 任务状态段类型值		*/
#define	DA_386CGate		0x8C	/* 386 调用门类型值			*/
#define	DA_386IGate		0x8E	/* 386 中断门类型值			*/
#define	DA_386TGate		0x8F	/* 386 陷阱门类型值			*/

/* 权限 */
#define	PRIVILEGE_KRNL	0
#define	PRIVILEGE_TASK	1
#define	PRIVILEGE_USER	3

/* 选择子 */
#define	SELECTOR_DUMMY		   0		// ┓
#define	SELECTOR_FLAT_C		0x08		// ┣ LOADER 里面已经确定了的.
#define	SELECTOR_FLAT_RW	0x10		// ┃
#define	SELECTOR_VIDEO		(0x18+3)	// ┛<-- RPL=3

#define	SELECTOR_KERNEL_CS	SELECTOR_FLAT_C
#define	SELECTOR_KERNEL_DS	SELECTOR_FLAT_RW

/* 段描述符 */
typedef struct s_descriptor
{
    unsigned short limit_low;          /* Limit */
    unsigned short base_low;           /* Base */
    unsigned char base_mid;            /* Base */
    unsigned char attr1;               /* P(1) DPL(2) DT(1) TYPE(4) */
    unsigned char limit_high_attr2;    /* G(1) D(1) 0(1) AVL(1) LimitHigh(4) */
    unsigned char base_high;           /* Base */
} DESCRIPTOR;

/* 门描述符 */
typedef struct s_gate
{
	unsigned short	offset_low;	/* Offset Low */
	unsigned short	selector;	/* Selector */
	unsigned char	dcount;		/* 该字段只在调用门描述符中有效 */
	unsigned char	attr;		/* P(1) DPL(2) DT(1) TYPE(4) */
	unsigned short	offset_high;	/* Offset High */
} GATE;

/* 中断处理函数 */
void	divide_error();
void	single_step_exception();
void	nmi();
void	breakpoint_exception();
void	overflow();
void	bounds_check();
void	inval_opcode();
void	copr_not_available();
void	double_fault();
void	copr_seg_overrun();
void	inval_tss();
void	segment_not_present();
void	stack_exception();
void	general_protection();
void	page_fault();
void	copr_error();

void    hwint00();
void    hwint01();
void    hwint02();
void    hwint03();
void    hwint04();
void    hwint05();
void    hwint06();
void    hwint07();
void    hwint08();
void    hwint09();
void    hwint10();
void    hwint11();
void    hwint12();
void    hwint13();
void    hwint14();
void    hwint15();
#endif
