[SECTION .data]
disp_pos	dd	0

[SECTION .text]

global  memcpy
global  disp_str
global  disp_pos

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
; void disp_str(char * info);
; ------------------------------------------------------------------------
disp_str:
	push	ebp
	mov	ebp, esp

	mov	esi, [ebp + 8]
	mov	edi, [disp_pos]

	mov	ah, 0Fh
.1:
	lodsb
	test	al, al
	jz	.2

	cmp	al, 0Ah
	jnz	.3

	push eax
	mov	eax, edi
	mov	bl, 160
	div	bl
	and	eax, 0FFh
	inc	eax
	mov	bl, 160
	mul	bl
	mov	edi, eax
	pop	eax
	jmp	.1
.3:
	mov	[gs:edi], ax
	add	edi, 2
	jmp	.1

.2:
	mov	[disp_pos], edi

	pop	ebp
	ret

