#ifndef _TECHLOGOS_FUNCTIONS_H_
#define _TECHLOGOS_FUNCTIONS_H_

typedef void (*int_handler) ();

void* memcpy(void* pDst, void* pSrc, int iSize);
void disp_int(int input);
void clear_screen();
void print_with_color(char *str, int color);
void print(char *str);

extern int disp_pos;
extern void out_byte(unsigned short port, unsigned char value);
extern unsigned char in_byte(unsigned short port);
extern unsigned char in_byte(unsigned short port);
extern void disp_char(char * info, int color);

#endif
