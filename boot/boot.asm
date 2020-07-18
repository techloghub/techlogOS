org  07c00h

BaseOfStack				equ	07c00h	; Boot状态下堆栈基地址(栈底, 从这个位置向低地址生长)
BaseOfLoader			equ	09000h	; LOADER.BIN 被加载段地址
OffsetOfLoader			equ	0100h	; LOADER.BIN 被加载偏移地址

RootDirSectors			equ	14		; 根目录区扇区数
SectorNoOfRootDirectory	equ	19		; Root Directory 的第一个扇区号
SectorNoOfFAT1			equ	1		; FAT1 的第一个扇区号 = BPB_RsvdSecCnt
DeltaSectorNo			equ	17		; 用于计算文件的开始扇区号 BPB_RsvdSecCnt + (BPB_NumFATs * FATSz) - 2

	jmp short LABEL_START			; Start to boot.
	nop								; jmp 语句 3 字节，nop 补足 4 字节

%include "fat12hdr.asm"

LABEL_START:	
	mov	ax, cs
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	mov	sp, BaseOfStack

	; 清屏
	mov	ax, 0600h		; AH = 6,  AL = 0h
	mov	bx, 0700h		; 黑底白字(BL = 07h)
	mov	cx, 0			; 左上角: (0, 0)
	mov	dx, 0184fh		; 右下角: (80, 50)
	int	10h

	mov	dh, 0
	call	DispStr
	
	; 复位软驱
	xor	ah, ah
	xor	dl, dl
	int	13h
	
; 在根目录区寻找 LOADER.BIN
	; wSectorNo 为根目录区扇区号，初始为 19
	mov	word [wSectorNo], SectorNoOfRootDirectory
LABEL_SEARCH_IN_ROOT_DIR_BEGIN:
	; 根目录区已读完，则说明未找到
	cmp	word [wRootDirSizeForLoop], 0
	jz	LABEL_NO_LOADERBIN
	dec	word [wRootDirSizeForLoop]

	; 读取扇区
	mov	ax, BaseOfLoader
	mov	es, ax
	mov	bx, OffsetOfLoader
	mov	ax, [wSectorNo]
	mov	cl, 1
	call	ReadSector

	mov	si, LoaderFileName			; ds:si = "LOADER  BIN"
	mov	di, OffsetOfLoader			; es:di = BaseOfLoader:0100
	cld								; df = 0

	; 循环读取目录条目
	mov	dx, 10h						; 当前扇区所有目录条目循环次数
LABEL_SEARCH_FOR_LOADERBIN:
	; 循环结束，已完成当前扇区目录条目读取
	cmp	dx, 0
	jz	LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR	
	dec	dx

	; 比较目录条目中 DIR_Name 是否与 LOADER.BIN 相同
	mov	cx, 11
LABEL_CMP_FILENAME:
	cmp	cx, 0
	jz	LABEL_FILENAME_FOUND		; 如果比较了 11 个字符都相等, 表示找到
	dec	cx
	lodsb							; ds:si -> al
	cmp	al, byte [es:di]
	jz	LABEL_GO_ON
	jmp	LABEL_DIFFERENT				; 字符不同，说明当前非目录条目
LABEL_GO_ON:
	inc	di
	jmp	LABEL_CMP_FILENAME

; 非当前条目，跳至下一条目
LABEL_DIFFERENT:
	and	di, 0FFE0h					; 让 es:di 指向当前条目起始位置
	add	di, 20h						; 跳至下一条目
	mov	si, LoaderFileName
	jmp	LABEL_SEARCH_FOR_LOADERBIN

; 非当前扇区，跳至下一扇区
LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR:
	add	word [wSectorNo], 1
	jmp	LABEL_SEARCH_IN_ROOT_DIR_BEGIN

; 未找到，终止流程
LABEL_NO_LOADERBIN:
	mov	dh, 2						; "No LOADER."
	call DispStr					; 显示字符串
	jmp	$

; 找到 loader.bin，继续流程
LABEL_FILENAME_FOUND:
	; 获取 loader.bin 对应的数据区簇号，保存在栈中
	and	di, 0FFE0h					; di = 当前条目起始位置
	add	di, 01Ah					; es:di 指向 DIR_FstClus，对应数据区簇号
	mov	cx, word [es:di]
	push cx

	; 获取文件所在扇区号，保存在 cx 中
	mov	ax, RootDirSectors			; 根目录扇区数
	add	cx, ax						; 因为 BPB_SecPerClus 为 1，每簇 1 扇区
	add	cx, DeltaSectorNo			; 所以，文件所在扇区号 = 根目录起始扇区号 + 根目录扇区数 + 文件数据区簇号 - 2

	; es:bx = loader.bin 将要被加载到的内存物理地址
	mov	ax, BaseOfLoader
	mov	es, ax
	mov	bx, OffsetOfLoader

	; 循环读取 loader.bin
	mov	ax, cx						; ax <- Sector 号
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

	mov	cl, 1
	call	ReadSector
	pop	ax							; 取出此 Sector 在 FAT 中的序号
	call	GetFATEntry				; 读取 FAT 项值
	cmp	ax, 0FFFh					; 判断是否完成读取
	jz	LABEL_FILE_LOADED
	push	ax						; 保存 Sector 在 FAT 中的序号

	; 读取文件下一簇
	mov	dx, RootDirSectors
	add	ax, dx
	add	ax, DeltaSectorNo
	add	bx, [BPB_BytsPerSec]
	jmp	LABEL_GOON_LOADING_FILE
LABEL_FILE_LOADED:
	; 完成文件读取，并全部载入内存
	mov	dh, 1						; "Ready."
	call	DispStr					; 显示字符串

	jmp	BaseOfLoader:OffsetOfLoader	; 跳转到已加载到内

; -------------------------- 变量 --------------------------------
wRootDirSizeForLoop	dw	RootDirSectors		; Root Directory 占用的扇区数, 在循环中会递减至零.
wSectorNo			dw	0					; 要读取的扇区号
bOdd				db	0					; 奇数还是偶数
LoaderFileName		db	"LOADER  BIN", 0	; LOADER.BIN 之文件名
; 为简化代码, 下面每个字符串的长度均为 MessageLength
MessageLength		equ	9
BootMessage:		db	"Booting  "			; 9字节, 不够则用空格补齐. 序号 0
Message1			db	"Ready.   "			; 9字节, 不够则用空格补齐. 序号 1
Message2			db	"No LOADER"			; 9字节, 不够则用空格补齐. 序号 2

; ---- 显示一个字符串, 函数开始时 dh 中应该是字符串序号(0-based) ----
DispStr:
	mov	ax, MessageLength
	mul	dh
	add	ax, BootMessage
	mov	bp, ax			; ┓
	mov	ax, ds			; ┣ ES:BP = 串地址
	mov	es, ax			; ┛
	mov	cx, MessageLength	; CX = 串长度
	mov	ax, 01301h		; AH = 13,  AL = 01h
	mov	bx, 0007h		; 页号为0(BH = 0) 黑底白字(BL = 07h)
	mov	dl, 0
	int	10h			; int 10h
	ret


; ----- 从第 ax 个 Sector 开始, 将 cl 个 Sector 读入 es:bx 中 -----
ReadSector:
	push	bp
	mov	bp, sp
	sub	esp, 2 					; 开辟两个字节的堆栈区域保存要读的扇区数: byte [bp-2]

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

	; 在 BaseOfLoader 后面留出 4K 空间用于存放 FAT
	mov	ax, BaseOfLoader
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
	mov	bx, 0 				; bx <- 0 于是, es:bx = (BaseOfLoader - 100):00
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

times 	510-($-$$)	db	0	; 填充剩余空间，使生成的二进制代码恰好为512字节
dw 	0xaa55					; 结束标志
