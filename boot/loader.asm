org	0100h
jmp	LABEL_START

; ------------- 描述符宏 ---------------
; usage: Descriptor Base, Limit, Attr
;        Base:  dd
;        Limit: dd (low 20 bits available)
;        Attr:  dw (lower 4 bits of higher byte are always 0)
%macro Descriptor 3
	dw	%2 & 0FFFFh							; 段界限1
	dw	%1 & 0FFFFh							; 段基址1
	db	(%1 >> 16) & 0FFh					; 段基址2
	dw	((%2 >> 8) & 0F00h) | (%3 & 0F0FFh)	; 属性1 + 段界限2 + 属性2
	db	(%1 >> 24) & 0FFh					; 段基址3
%endmacro

; -------------- GDT -------------
;                            段基址     段界限, 属性
LABEL_GDT:			Descriptor 0,            0, 0			; 空描述符
LABEL_DESC_FLAT_C:  Descriptor 0,      0fffffh, 0C09Ah		; 4GB 可执行代码段
LABEL_DESC_FLAT_RW: Descriptor 0,      0fffffh, 0C092h		; 4GB 可读写数据段
LABEL_DESC_VIDEO:   Descriptor 0B8000h, 0ffffh, 0f2h		; 显存段

GdtLen	equ	$ - LABEL_GDT
GdtPtr	dw	GdtLen - 1							; 段界限
		dd	BaseOfLoaderPhyAddr + LABEL_GDT		; 基地址

; ----------- GDT 选择子 ----------
SelectorFlatC			equ	LABEL_DESC_FLAT_C	- LABEL_GDT
SelectorFlatRW			equ	LABEL_DESC_FLAT_RW	- LABEL_GDT
SelectorVideo			equ	LABEL_DESC_VIDEO	- LABEL_GDT + 3


BaseOfLoader	    	equ	 09000h					; LOADER.BIN 被加载到的段地址
OffsetOfLoader	    	equ	  0100h					; LOADER.BIN 被加载到的偏移地址
BaseOfLoaderPhyAddr 	equ	BaseOfLoader*10h		; LOADER.BIN 被加载到的物理地址

BaseOfKernelFile    	equ	 08000h					; KERNEL.BIN 被加载到的位置段地址
OffsetOfKernelFile  	equ	     0h					; KERNEL.BIN 被加载到的位置偏移地址
BaseOfKernelFilePhyAddr	equ	BaseOfKernelFile * 10h	; KERNEL.BIN 被加载到的物理地址
KernelEntryPointPhyAddr	equ	 10000h					; KERNEL ELF header e_entry 值，起始物理地址

BaseOfStack	equ	0100h
PageDirBase	equ	100000h	; 页目录开始地址: 1M
PageTblBase	equ	101000h	; 页表开始地址:   1M + 4K

; FAT12 头
%include	"fat12hdr.asm"

LABEL_START:
	mov	ax, cs
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	mov	sp, BaseOfStack

	mov	dh, 0					; "Loading  "
	call	DispStrRealMode		; 显示字符串

; ----------- 获取内存信息 -------------
	mov	ebx, 0
	mov	di, _MemChkBuf			; es:di 存储地址范围描述符结构 ARDS
.MemChkLoop:
	mov	eax, 0E820h				; eax = 0000E820h
	mov	ecx, 20					; ecx = 地址范围描述符结构大小
	mov	edx, 0534D4150h			; edx = 'SMAP'
	int	15h
	jc	.MemChkFail
	add	di, 20
	inc	dword [_dwMCRNumber]	; dwMCRNumber = ARDS 的个数
	cmp	ebx, 0
	jne	.MemChkLoop
	jmp	.MemChkOK
.MemChkFail:
	mov	dword [_dwMCRNumber], 0
.MemChkOK:

; ----- 在 A 盘根目录寻找 KERNEL.BIN -----
	mov	word [wSectorNo], SectorNoOfRootDirectory	

	; 软盘复位
	xor	ah, ah
	xor	dl, dl
	int	13h

LABEL_SEARCH_IN_ROOT_DIR_BEGIN:
	; 根目录已读取完成，未找到 kernel.bin
	cmp	word [wRootDirSizeForLoop], 0
	jz	LABEL_NO_KERNELBIN

	; 读取根目录区一个扇区
	dec	word [wRootDirSizeForLoop]
	mov	ax, BaseOfKernelFile
	mov	es, ax						; es <- BaseOfKernelFile
	mov	bx, OffsetOfKernelFile		; bx <- OffsetOfKernelFile
	mov	ax, [wSectorNo]				; ax <- Root Directory 中的某 Sector 号
	mov	cl, 1
	call	ReadSector

	mov	si, KernelFileName			; ds:si = "KERNEL  BIN"
	mov	di, OffsetOfKernelFile		; es:di = BaseOfKernelFile:OffsetOfKernelFile
	cld								; df = 0

	; 循环读取目录条目
	mov	dx, 10h						; 当前扇区所有目录条目循环次数
LABEL_SEARCH_FOR_KERNELBIN:
	; 已读取完该扇区
	cmp	dx, 0				  ; `.
	jz	LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR
	dec	dx

	; 比较文件名
	mov	cx, 11
LABEL_CMP_FILENAME:
	cmp	cx, 0
	jz	LABEL_FILENAME_FOUND		; 已找到 kernel
	dec	cx
	lodsb
	cmp	al, byte [es:di]
	jz	LABEL_GO_ON
	jmp	LABEL_DIFFERENT
LABEL_GO_ON:
	inc	di
	jmp	LABEL_CMP_FILENAME

; 跳转到下一条目
LABEL_DIFFERENT:
	and	di, 0FFE0h					; 让 es:di 指向当前条目起始位置
	add	di, 20h						; 跳至下一条目
	mov	si, KernelFileName
	jmp	LABEL_SEARCH_FOR_KERNELBIN

; 跳转到下一扇区
LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR:
	add	word [wSectorNo], 1
	jmp	LABEL_SEARCH_IN_ROOT_DIR_BEGIN

; 未找到，显示字符串，终止流程
LABEL_NO_KERNELBIN:
	mov	dh, 2						; "No KERNEL."
	call	DispStrRealMode					; 显示字符串
	jmp	$

; 找到 kernel，加载
LABEL_FILENAME_FOUND:
	; 保存 kernel.bin 的文件大小
	mov	 eax, [es : di + 01Ch]
	mov	 dword [dwKernelSize], eax

	; 获取 loader.bin 对应的数据区簇号，保存在栈中
	and	 di, 0FFF0h
	add	 di, 01Ah
	mov	 cx, word [es:di]
	push cx

	; 获取文件所在扇区号，保存在 cx 中
	mov	ax, RootDirSectors
	add	cx, ax
	add	cx, DeltaSectorNo

	; es:bx = kernel.bin 将要被加载到的内存物理地址
	mov	ax, BaseOfKernelFile
	mov	es, ax
	mov	bx, OffsetOfKernelFile

	; 循环读取 kernel.bin
	mov	ax, cx
LABEL_GOON_LOADING_FILE:
	; 打点，表示准备读取一个扇区，展示 Booting....
	push	ax
	push	bx
	mov	ah, 0Eh
	mov	al, '.'
	mov	bl, 0Fh
	int	10h
	pop	bx
	pop	ax

	; 根据 FAT 项值循环读取簇
	mov	 cl, 1
	call ReadSector
	pop	 ax
	call GetFATEntry
	cmp	 ax, 0FFFh
	jz	 LABEL_FILE_LOADED
	push ax
	mov	 dx, RootDirSectors
	add	 ax, dx
	add	 ax, DeltaSectorNo
	add	 bx, [BPB_BytsPerSec]
	jmp	 LABEL_GOON_LOADING_FILE

; 加载完成
LABEL_FILE_LOADED:
	; 关闭软驱
	call	KillMotor

	; 显示字符串
	mov	dh, 1
	call	DispStrRealMode

; ------------ 跳转进入保护模式 -------------
	; 加载 GDTR
	lgdt	[GdtPtr]

	; 关中断
	cli

	; 打开地址线A20
	in	al, 92h
	or	al, 00000010b
	out	92h, al

	; 准备切换到保护模式
	mov	eax, cr0
	or	eax, 1
	mov	cr0, eax

	; 真正进入保护模式
	jmp	dword SelectorFlatC:(BaseOfLoaderPhyAddr+LABEL_PM_START)

	jmp	$

; ---- 显示一个字符串, 函数开始时 dh 中存储字符串序号(0-based) ----
DispStrRealMode:
	mov	ax, MessageLength
	mul	dh
	add	ax, LoadMessage
	mov	bp, ax				; ┓
	mov	ax, ds				; ┣ ES:BP = 串地址
	mov	es, ax				; ┛
	mov	cx, MessageLength	; CX = 串长度
	mov	ax, 01301h			; AH = 13,  AL = 01h
	mov	bx, 0007h			; 页号为0(BH = 0) 黑底白字(BL = 07h)
	mov	dl, 0
	add	dh, 3				; 从第 3 行往下显示
	int	10h
	ret

; ------------- 关闭软驱 -----------
KillMotor:
	push	dx
	mov	dx, 03F2h
	mov	al, 0
	out	dx, al
	pop	dx
	ret

; ----- 从第 ax 个 Sector 开始, 将 cl 个 Sector 读入 es:bx 中 -----
ReadSector:
	push	bp
	mov	bp, sp
	sub	esp, 2 					; 开辟两个字节的堆栈区域存储扇区数

	mov	 byte [bp-2], cl
	push bx
	mov	 bl, [BPB_SecPerTrk]	; bl: 每磁道扇区数
	div	bl						; 商保存在 al 中，余数保存在 ah 中
	inc	ah						; 获取其实扇区号
	mov	cl, ah					; cl <- 起始扇区号
	mov	dh, al
	shr	al, 1					; 获取柱面号
	mov	ch, al					; ch <- 柱面号
	and	dh, 1					; 获取磁头号
	pop	bx
	mov	dl, [BS_DrvNum]			; 驱动器号 (0 表示 A 盘)
.GoOnReading:
	mov	ah, 2					; 读
	mov	al, byte [bp-2]			; 读 al 个扇区
	int	13h
	jc	.GoOnReading			; 如果读取错误 CF 会被置为 1, 这时就不停地读, 直到正确为止
	add	esp, 2
	pop	bp

	ret

; ---- 读取序号为 ax 的 Sector 在 FAT 中的条目, 放在 ax 中 ----
GetFATEntry:
	push	es
	push	bx
	push	ax

	; 在 BaseOfKernelFile 后面留出 4K 空间用于存放 FAT
	mov	ax, BaseOfKernelFile
	sub	ax, 0100h
	mov	es, ax

	; 判断 ax 奇偶性，赋值 bOdd 变量
	pop	ax
	mov	byte [bOdd], 0		; bOdd 变量用于存放当前是奇数次读取还是偶数次读取
	mov	bx, 3
	mul	bx					; dx:ax = ax * 3
	mov	bx, 2
	div	bx					; dx:ax / 2  ==>  ax <- 商, dx <- 余数
	cmp	dx, 0
	jz	LABEL_EVEN
	mov	byte [bOdd], 1		; 奇数

LABEL_EVEN:
	; 计算 FAT 项所在扇区号
	xor	dx, dx			
	mov	bx, [BPB_BytsPerSec]
	div	bx 					; dx:ax / BPB_BytsPerSec
		   					; ax <- 商 (FATEntry 所在的扇区相对于 FAT 的扇区号)
		   					; dx <- 余数 (FATEntry 在扇区内的偏移)
	push dx
	mov	bx, 0 				; bx <- 0 于是, es:bx = (BaseOfKernelFile - 100):00
	add	ax, SectorNoOfFAT1	; ax = FAT1 起始扇区号 + 指定读取扇区号 = FATEntry 所在的扇区号
	mov	cl, 2
	call ReadSector 		; 读取 FATEntry 所在的扇区, 一次读两个

	; 赋值结果给 ax 并矫正结果
	pop	dx
	add	bx, dx
	mov	ax, [es:bx]
	cmp	byte [bOdd], 1
	jnz	LABEL_EVEN_2
	shr	ax, 4
LABEL_EVEN_2:
	and	ax, 0FFFh

LABEL_GET_FAT_ENRY_OK:

	pop	bx
	pop	es
	ret

; --------------- 变量 ----------------
wRootDirSizeForLoop	dw	RootDirSectors		; Root Directory 占用的扇区数
wSectorNo			dw	0					; 要读取的扇区号
bOdd				db	0					; 奇数还是偶数
dwKernelSize		dd	0					; KERNEL.BIN 文件大小

; -------------- 字符串 ----------------
KernelFileName		db	"KERNEL  BIN", 0	; KERNEL.BIN 文件名
MessageLength		equ	9
LoadMessage:		db	"Loading  "
Message1			db	"Ready.   "
Message2			db	"No KERNEL"

; ------------ 32 位代码段 -------------
[SECTION .s32]
ALIGN	32
[BITS	32]

LABEL_PM_START:
	mov	ax, SelectorVideo
	mov	gs, ax

	mov	ax, SelectorFlatRW
	mov	ds, ax
	mov	es, ax
	mov	fs, ax
	mov	ss, ax
	mov	esp, TopOfStack

	call	DispMemInfo
	call	SetupPaging

	push	szMemChkTitle
	call	DispStr
	add	esp, 4

	call	InitKernel
	jmp	SelectorFlatC : KernelEntryPointPhyAddr	; 跳转进入内核

%include	"lib.asm"

DispMemInfo:
	push	esi
	push	edi
	push	ecx

	; 循环获取 ARDS 4 个成员
	mov	esi, MemChkBuf  		; 寻址缓存区
	mov	ecx, [dwMCRNumber]		; 获取循环次数 ARDS 个数
.loop:
	mov	edx, 5					; 循环遍历 ARDS 的 4 个成员
	mov	edi, ARDStruct
.1:

	; 将缓冲区中成员赋值给 ARDStruct
	mov eax, dword [esi]
	stosd

	add	esi, 4
	dec	edx
	cmp	edx, 0
	jnz	.1

	; Type 是 AddressRangeMemory 赋值 dwMemSize
	cmp	dword [dwType], 1
	jne	.2
	mov	eax, [dwBaseAddrLow]
	add	eax, [dwLengthLow]
	cmp	eax, [dwMemSize]
	jb	.2
	mov	[dwMemSize], eax
.2:
	loop	.loop

	pop	ecx
	pop	edi
	pop	esi
	ret

; 启动分页机制 --------------------------------------------------------------
SetupPaging:
	; 根据内存大小计算应初始化多少PDE以及多少页表
	xor	edx, edx
	mov	eax, [dwMemSize]
	mov	ebx, 400000h		; 400000h = 4M = 4096 * 1024, 一个页表对应的内存大小
	div	ebx
	mov	ecx, eax			; 此时 ecx 为页表的个数，也即 PDE 应该的个数
	test	edx, edx
	jz	.no_remainder
	inc	ecx					; 如果余数不为 0 就需增加一个页表
.no_remainder:
	push	ecx				; 暂存页表个数

	; 首先初始化页目录
	mov	ax, SelectorFlatRW
	mov	es, ax
	mov	edi, PageDirBase	; 此段首地址为 PageDirBase
	xor	eax, eax
	mov	eax, PageTblBase | 7
.1:
	stosd
	add	eax, 4096			; 为了简化, 所有页表在内存中是连续的
	loop	.1

	; 再初始化所有页表
	pop	eax					; 页表个数
	mov	ebx, 1024			; 每个页表 1024 个 PTE
	mul	ebx
	mov	ecx, eax			; PTE个数 = 页表个数 * 1024
	mov	edi, PageTblBase	; 此段首地址为 PageTblBase
	xor	eax, eax
	mov	eax, 7 
.2:
	stosd
	add	eax, 4096			; 每一页指向 4K 的空间
	loop	.2

	mov	eax, PageDirBase
	mov	cr3, eax
	mov	eax, cr0
	or	eax, 80000000h
	mov	cr0, eax
	jmp	short .3
.3:
	nop

	ret

; ------------------- 放置 kernel -----------------
InitKernel:
    xor   esi, esi
    mov   cx, word [BaseOfKernelFilePhyAddr + 2Ch]  ; cx 存储 ELF header e_phnum 字段，program header 条目数
    movzx ecx, cx                                   ; 将 cx 扩展为 ecx
    mov   esi, [BaseOfKernelFilePhyAddr + 1Ch]      ; esi 存储 ELF header e_phoff 字段，program header 偏移量
    add   esi, BaseOfKernelFilePhyAddr              ; esi 存储 program header 物理地址
.Begin:
    ; program header 空条目处理
    mov   eax, [esi + 0]							; 获取 program header 的 p_type 字段，为 0 表示该条目为空
    cmp   eax, 0
    jz    .NoAction

    ; 拷贝 program header 描述的内存段到目标内存地址
    push  dword [esi + 010h]                        ; p_filesz 内存段大小
    mov   eax, [esi + 04h]                          ; p_offset 段在文件中的偏移
    add   eax, BaseOfKernelFilePhyAddr              ; eax 存储内存段在 elf 文件中的起始物理地址
    push  eax
    push  dword [esi + 08h]                         ; p_vaddr 内存段目标虚拟地址
    call  MemCpy
    add   esp, 12

.NoAction:
    add   esi, 020h                                 ; 跳到下一条目
    loop  .Begin

    ret


; ------------------- 内存拷贝函数 -----------------
; void* MemCpy(void* es:pDest, void* ds:pSrc, int iSize);
; --------------------------------------------------
MemCpy:
	push	ebp
	mov	ebp, esp

	push	esi
	push	edi
	push	ecx

	mov	edi, [ebp + 8]	; Destination
	mov	esi, [ebp + 12]	; Source
	mov	ecx, [ebp + 16]	; Counter

	; 参数校验
	cmp ecx, 0
	jz .memcpy_end

.memcpy_loop:
	; 逐字节移动内存
	mov	al, [ds:esi]
	inc	esi
	mov	byte [es:edi], al
	inc	edi
	loop .memcpy_loop

.memcpy_end:
	mov	eax, [ebp + 8]	; 返回值

	pop	ecx
	pop	edi
	pop	esi
	mov	esp, ebp
	pop	ebp

	ret

; ---------------- 32 位数据段 ------------------
[SECTION .data1]
ALIGN	32

LABEL_DATA:
; 实模式下使用这些符号
; 字符串
_szMemChkTitle:	db "Welcome to loader by techlog.cn", 0Ah, 0
_szReturn:	db 0Ah, 0

; 变量
_dwMCRNumber:	dd 0	; Memory Check Result
_dwDispPos:	dd (80 * 6 + 0) * 2	; 屏幕第 6 行, 第 0 列
_dwMemSize:	dd 0
_ARDStruct:	; Address Range Descriptor Structure
  _dwBaseAddrLow:		dd	0
  _dwBaseAddrHigh:		dd	0
  _dwLengthLow:			dd	0
  _dwLengthHigh:		dd	0
  _dwType:			dd	0
_MemChkBuf:	times	256	db	0

; 保护模式下使用这些符号
szMemChkTitle		equ	BaseOfLoaderPhyAddr + _szMemChkTitle
szReturn			equ	BaseOfLoaderPhyAddr + _szReturn
dwDispPos			equ	BaseOfLoaderPhyAddr + _dwDispPos
dwMemSize			equ	BaseOfLoaderPhyAddr + _dwMemSize
dwMCRNumber			equ	BaseOfLoaderPhyAddr + _dwMCRNumber
ARDStruct			equ	BaseOfLoaderPhyAddr + _ARDStruct
	dwBaseAddrLow	equ	BaseOfLoaderPhyAddr + _dwBaseAddrLow
	dwBaseAddrHigh	equ	BaseOfLoaderPhyAddr + _dwBaseAddrHigh
	dwLengthLow	equ	BaseOfLoaderPhyAddr + _dwLengthLow
	dwLengthHigh	equ	BaseOfLoaderPhyAddr + _dwLengthHigh
	dwType			equ	BaseOfLoaderPhyAddr + _dwType
MemChkBuf			equ	BaseOfLoaderPhyAddr + _MemChkBuf

; 堆栈空间
StackSpace:	times	1024	db	0
TopOfStack	equ	BaseOfLoaderPhyAddr + $
