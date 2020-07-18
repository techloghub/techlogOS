[section .data]
randstr	db "Welcome to kernel by techlog.cn", 0

[section .text]
global _start

_start:
	push dword randstr
	call DispStr
	add esp, 4
	jmp	$

DispStr:
	push	ebp
	mov	ebp, esp
	push	ebx
	push	esi
	push	edi

	mov	esi, [ebp + 8]	; pszInfo
	mov	edi, (80 * 7) * 2
	mov	ah, 0Fh
.1:
	lodsb
	test	al, al
	jz	.2
.3:
	mov	[gs:edi], ax
	add	edi, 2
	jmp	.1

.2:
	pop	edi
	pop	esi
	pop	ebx
	pop	ebp
	ret
