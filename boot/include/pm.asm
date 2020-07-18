; 宏 ------------------------------------------------------------------------------------------------------
;
; 描述符宏
; usage: Descriptor Base, Limit, Attr
;        Base:  dd
;        Limit: dd (low 20 bits available)
;        Attr:  dw (lower 4 bits of higher byte are always 0)
%macro Descriptor 3
	dw	(%2) & 0FFFFh
	dw	(%1) & 0FFFFh
	db	((%1) >> 16) & 0FFh
	dw	((%2) >> 8) & 0F00h)
	db	((%1) >> 24) & 0FFh
%endmacro ; 共 8 字节
;
; 门
; usage: Gate Selector, Offset, DCount, Attr
;        Selector:  dw
;        Offset:    dd
;        DCount:    db
;        Attr:      db
%macro Gate 4
	dw	(%2 & 0FFFFh)				; 偏移 1				(2 字节)
	dw	%1					; 选择子				(2 字节)
	dw	(%3 & 1Fh) | ((%4 << 8) & 0FF00h)	; 属性					(2 字节)
	dw	((%2 >> 16) & 0FFFFh)			; 偏移 2				(2 字节)
%endmacro ; 共 8 字节
; ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
