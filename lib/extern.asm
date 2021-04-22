[SECTION .text]

global  memcpy
global  disp_char
global  in_byte
global  out_byte

extern disp_pos

; ------------------------------------------------------------------------
; void* memcpy(void* es:pDest, void* ds:pSrc, int iSize);
; ------------------------------------------------------------------------
memcpy:
	push	ebp
	mov	ebp, esp

	push	esi
	push	edi
	push	ecx

	mov	edi, [ebp + 8]	    ; Destination
	mov	esi, [ebp + 12]	    ; Source
	mov	ecx, [ebp + 16]	    ; Counter
.1:
	cmp	ecx, 0		        ; 判断计数器
	jz	.2		            ; 计数器为零时跳出

	mov	al, [ds:esi]		; ┓
	inc	esi			        ; ┃
					        ; ┣ 逐字节移动
	mov	byte [es:edi], al	; ┃
	inc	edi			        ; ┛

	dec	ecx		            ; 计数器减一
	jmp	.1		            ; 循环
.2:
	mov	eax, [ebp + 8]	    ; 返回值

	pop	ecx
	pop	edi
	pop	esi
	mov	esp, ebp
	pop	ebp

	ret

; ------------------------------------------------------------------------
; void out_byte(unsigned short port, unsigned char value);
; ------------------------------------------------------------------------
out_byte:
	mov	edx, [esp + 4]		; port
	mov	al, [esp + 4 + 4]	; value
	out	dx, al
	nop	                    ; 延迟等待硬件操作完成
	nop
	ret

; ------------------------------------------------------------------------
; unsigned char in_byte(unsigned short port);
; ------------------------------------------------------------------------
in_byte:
	mov	edx, [esp + 4]		; port
	xor	eax, eax
	in	al, dx
	nop                     ; 延迟等待硬件操作完成
	nop
	ret

; ------------------------------------------------------------------------
; void disp_char(char * info, int color);
; ------------------------------------------------------------------------
disp_char:
	push	ebp
	mov	ebp, esp

	mov	esi, [ebp + 8]	; pszInfo
	mov	edi, [disp_pos]
	mov	ah, [ebp + 12]	; color

	lodsb
	mov	[gs:edi], ax
	add	edi, 2

	pop	ebp
	ret
