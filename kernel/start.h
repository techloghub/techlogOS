#ifndef _TECHLOGOS_START_H_
#define _TECHLOGOS_START_H_

/* GDT 中描述符的个数 */
#define GDT_SIZE 128
void* memcpy(void* pDst, void* pSrc, int iSize);
void disp_str(char * pszInfo);
void clear_screen();

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

#endif
