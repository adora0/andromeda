	/*
	* Boot sector
	* Loads and executes the kernel loader from disk
	*/
	
	.code16

	.section .text
	.global _start

	/*
	* No addresses after 1MiB +64KiB can be used before
	* the A20 gate is enabled in the kernel loader
	*/

	/*
	* 4KiB stack before boot code
	* Conventional memory space 0x500-0x7BFF
	*/

	.set STACK_TOP,		0x1500
	.set STACK_BASE,	0x0500

	/*
	* Offset address to load the root directory and FAT
	* Conventional memory space 0x7E00-0x7FFFF
	* 4KiB space before load address
	*/

	.set DATA_ADDR,		0x7E00

	/*
	* Offset address to load the loader binary
	*/

	.set LOAD_ADDR,		0x9E00


_start:
	/* E9 .. 90 opcodes (jmp short; nop) required by BIOS parameter block */

	jmp	main
	nop

/*
* FAT12/16 BIOS parameter block (BPB)
* Parameters set by formatting tools
*/

	. = _start + 0x03

bpb_oem_id:		.space	8, 0	// OEM identifier (max. 8 bytes, space-padded)
bpb_sector_size:	.word	0	// bytes per sector
bpb_sectors_cluster:	.byte	0	// sectors per cluster
bpb_reserved_sectors:	.word	0	// reserved (boot sector only)
bpb_fat_count:		.byte	0	// number of file allocation tables (FATs)
bpb_root_entries:	.word	0	// number of root directory entries (must span sectors)
bpb_sector_count:	.word	0	// number of 16-bit locgical sectors
bpb_media_type:		.byte	0	// media descriptor
bpb_sectors_fat:	.word	0	// sectors per FAT
bpb_sectors_track:	.word	0	// sectors per track
bpb_head_count:		.word	0	// number of heads on storage media
bpb_hidden_sectors:	.long	0	// number of hidden sectors
bpb_large_sectors:	.long	0	// number of 32-bit sectors

/*
* FAT12/16 Extended Boot Record (EBPB)
*/

	. = _start + 0x024

ebpb:
ebpb_drive_num:		.byte	0	// BIOS drive number (int 0x13)
ebpb_nt_flags:		.byte	0	// Windows NT flags (reserved)
ebpb_volume_signature:	.byte	0	// volume signature (0x28 or 0x29)
ebpb_volume_serial:	.space	4, 0	// serial for volume tracking (32-bit hex)
ebpb_volume_label:	.space	11, 0	// volume label string (max. 11 bytes, space-padded)
ebpb_system_id:		.space	8, 0	// file system type representation (unused)


/*
* End of parameter block
*/

	. = _start + 0x03E


/*
* Disk geometry space
*/

drive_number:		.byte	0
disk_cluster:		.word	0
disk_data_sector:	.word	0

/*
* Entry point
*/

main:
	ljmp	$0, $1f		// reset code segment
1:	cld			// clear direction flag for string operations
	cli			// disable interrupts for setup
	

	/* Initialize stack */

	xor	%ax, %ax
	movw	%ax, %ss		// reset stack segment
	mov	$STACK_TOP, %sp		// set stack top
	mov	$STACK_BASE, %bp	// set stack base

	movb	%dl, drive_number	// save drive number set by BIOS
	
	sti			// restore interrupts
	

	/* Read root directory */

	xor 	%ax, %ax
	mov 	%ax, %es		// clear destination segment
	mov 	$DATA_ADDR, %di		// set destination offset
	call 	load_root		// read
	jc 	err_disk
	movw 	%bx, disk_data_sector	// store first data sector


	/* Find kernel loader in root directory at ES:DI */

	xor 	%ax, %ax
	mov 	%ax, %es		// clear root directory segment
	mov	$DATA_ADDR, %di		// set root directory offset
	mov 	%ax, %dx		// clear filename segment
	lea 	filename, %si		// set filename offset
	call 	find_file		// find
	jc 	err_no_file
	movw 	%bx, disk_cluster	// store first cluster


	/* Load the FAT at location ES:DI */

	xor 	%ax, %ax
	mov 	%ax, %es		// clear FAT segment
	mov	$DATA_ADDR, %di		// set FAT offset
	call 	load_fat


	/* Read file clusters */

	xor 	%ax, %ax
	mov 	%ax, %dx		// clear FAT segment
	mov	$DATA_ADDR, %si		// set FAT offset
	mov 	%ax, %es		// clear destination segment
	mov 	$LOAD_ADDR, %di		// set destination offset
	movw 	disk_cluster, %ax	// first cluster
	call	load_file		// read
	jc 	err_disk


	/* Execute the loader */

	ljmp	$(LOAD_ADDR >> 4), $0	// jump and update segment


/*
* Halt execution
*/

_end:
	cli
1:	hlt
	jmp 1b


/***************
* Functions
***************/


/*
* Output a null-terminated string in text mode
*	in:	SI -> string
*/

puts:
	pusha

1:	lodsb			// load character from SI into AL
	or	%al, %al
	jz	2f		// exit on null byte

	mov	$0x0E, %ah	// teletype output
	xor	%bx, %bx	// BH = 0 (page number), BL = 0 (foreground color)
	int	$0x10
	jmp	1b		// next
2:	popa

	ret


/*
* Read file clusters from FAT
*	in:	AX = index of first cluster
*		DX:SI -> FAT
*		ES:DI -> destination
*	out:	data at ES:DI	
*/

load_file:
	pusha

1:	push	%ax			// save cluster index

	/*
	* Calculate LBA of cluster in ax
	* LBA = (cluster - 2) * sectors per cluster + first data sector
	*/


	sub	$2, %ax				// cluster - 2
	xor	%ch, %ch
	movb	bpb_sectors_cluster, %cl
	mul	%cx				// * sectors per cluster
	addw	disk_data_sector, %ax		// + first data sector

	/*
	* Read cluster
	* AX = cluster LBA, CX = sectors per cluster, ES:DI -> destination
	*/

	call	disk_read
	jc	4f


	/*
	* Calculate next cluster;
	* Each 12-bit cluster is not 16-bit aligned,
	* so values must be adjusted to only read
	* a single cluster when copying a word.
	*
	* If previous cluster was even, mask the top 4 bits belonging to the next cluster 
	* If previous cluster was odd, shift the address down 4 bits to discard the bits used by the previous cluster
	*/

	pop	%ax			// restore current cluster
	push	%ax			// save current cluster to check
	push	%ds			// save segment
	push	%si			// save offset
	
	mov	%ax, %bx		// copy index
	shr	%bx			// divide by 2
	add	%bx, %ax		// add to AX for 3/2 of current index
	add	%ax, %si		// add index to offset of FAT		
	mov	%dx, %ds		// segment of FAT


	/* Read cluster index from FAT */

	lodsw				// read word from DS:SI into AX

	pop	%si			// restore offset
	pop	%ds			// restore segment

	pop	%bx			// get previous cluster
	test	$1, %bx			// check least significant bit
	jz	2f			// last cluster index was even


	/* Odd cluster */

	shr	$4, %ax			// get high twelve bits
	jmp	3f


2:	/* Even cluster */

	and	$0x0F, %ah		// get low twelve bits


3:	cmp	$0x0FF8, %ax		// exit at end of chain
	jl	1b			// next cluster if less than final identifier


4:	/* End */

	popa
	ret


/*
* Read sectors from disk
*	in:	AX = LBA
*		CX = number of sectors
*		ES:DI -> buffer
*
*	out:	data at ES:DI
*		CF set on error after 3 retries
*		ES:DI updated to end of buffer
*/

disk_read:
	/* Save registers for return */
	
	push	%ax
	push	%bx
	push	%cx
	push	%dx
	push	%si

	mov	%cx, %si		// store number of sectors
	mov	$3, %cx			// set counter to remaining attempts

1:	push	%cx			// store counter
	push	%ax			// store LBA


	/*
	* LBA to CHS conversion
	*	track = LBA / (sectors per track * number of heads)
	*	head = (LBA / sectors per track) % sectors per track
	*	sector = (LBA / sectors per track) + 1
	*/

	xor	%dx, %dx		// prepare DX:AX for operation
	divw	bpb_sectors_track	// LBA / sectors per track
	inc	%dl			// adjust for sector 0
	mov	%dl, %cl		// CL = sector (quotient)

	xor	%dx, %dx		// prepare DX:AX for operation
	divw	bpb_head_count		// / sectors per track
	mov	%dl, %dh		// DH = head (quotient)

	mov	%al, %ch		// CH = track (remainder)

	clc				// clear carry flag


	/*
	* Int 0x13/AH=0x02: Disk - Read sectors into memory
	*	in:	AH = 0x02
	*		AL = number of sectors to read
	*		CH = lower eight bits of cylinder number
	*		CL = sector number
	*		DH = head number
	*		DL = drive number
	*		ES:BX -> data buffer
	*/

	mov	$0x0201, %ax		// read 1 sector
	movb	drive_number, %dl	// DL = drive number
	mov 	%di, %bx		// BX = offset

	int	$0x13

	jnc	2f			// prepare for next read if success

	xor	%ah, %ah		// reset disk on failure
	int	$0x13

	pop	%ax			// restore LBA
	pop	%cx			// restore counter
	loop	1b			// retry if attempts remaining

	jmp	3f			// fail


2:	/* Increment buffer pointer by 1 sector */

	addw	bpb_sector_size, %di	// add sector size to offset
	shr	$4, %di			// get effective segment (offset >> 4)
	mov	%es, %ax
	add	%ax, %di		// add initial segment
	mov	%di, %es		// store in ES
	xor	%di, %di		// clear offset

	pop	%ax			// restore LBA
	pop	%cx			// restore counter

	dec	%si			// decrement remaining sectors
	jz	4f			// exit if complete

	inc	%ax			// increment LBA
	jmp	1b			// read next sector


3:	stc				// set carry flag on failure


4:	/* End */

	pop    %si
        pop    %dx
        pop    %cx
        pop    %bx
        pop    %ax
	ret


/*
* Read FAT12/16 root directory
*	in:	ES:DI -> buffer
*
*	out:	data at ES:DI
*               BX = first data sector
*		CF set on error
*/

load_root:
	/* Store size in cx */

	mov	$32, %ax		// root entry size
	mulw	bpb_root_entries	// * number of entries
	divw	bpb_sector_size		// / sector size
	mov	%ax, %cx		// number of sectors


	/*
	* Store location in ax
	* CHS = LBA when head = 0 and track = 0
	*/

	xor	%ax, %ax
	movb	bpb_fat_count, %al		// number of FATs
	mulw	bpb_sectors_fat			// * sectors per FAT
	addw	bpb_reserved_sectors, %ax	// + reserved sectors
	movw	%ax, %bx			// base of root directory
	addw	%cx, %bx			// + size
	

	/* Save registers */

	push	%es
	push 	%di


	/* Read root directory */

	clc
	call	disk_read		// read sectors


	/* Restore registers */

	pop	%di
	pop 	%es


	ret


/*
* Find file in FAT12/16 root directory
*	in:	DX:SI -> filename
*		ES:DI -> root directory
*
*	out:	BX = index of first cluster
*		CF set if not found
*/

find_file:
	/* Load size of root directory */

	movw	bpb_root_entries, %cx	// initialize counter


1:	/* Compare filenames */

	pusha			// save registers
	push	%ds
	push	%es
	
	mov	%dx, %ds	// filename segment
	
	mov	$11, %cx	// 11-byte filename length
rep	cmpsb			// compare each byte pair in DS:SI and ES:DI
	
	pop	%es		// restore registers
	pop	%ds
	popa
	
	je	2f		// continue if match
	add	$32, %di	// go to next entry if not matching
	loop	1b

	stc			// set carry flag if not found
	jmp 	3f


2:	/* Store index of first cluster */

	push	%ds
	push	%di
	push	%si

	mov	%es, %ax
	mov	%ax, %ds
	add	$26, %di	// get cluster bytes 26-27 from entry
	mov	%di, %si
	lodsw			// read word from DS:SI into ax
	
	pop	%si		// restore registers
	pop	%di
	pop	%ds

	mov	%ax, %bx	// BX = cluster


3:	/* End */

	ret


/*
* Load file allocation table
*	in:	ES:DI -> buffer
*
*	out:	data in ES:DI
*		CF set on error
*/

load_fat:
	/* Calculate size of FAT and store in cx */
	
	movw	bpb_sectors_fat, %ax	// sectors per FAT
	mulb	bpb_fat_count		// * number of FATs
	mov	%ax, %cx


	/* Save location in ax */
	
	movw	bpb_reserved_sectors, %ax


	/* Save registers */
	
	push	%es
	push 	%di


	/* Read FAT into buffer */
	
	clc
	call	disk_read


	/* Restore registers */
	
	pop	%di
	pop 	%es


	ret


/**************/


/*
* Loader filename
* 11 chars with no null termination
*/

filename:		.ascii  "LOADER  BIN"


/*
* Messages
*/

	.macro err str

	leaw	\str, %si
	call	puts
	jmp	_end

	.endm

msg_err_disk:		.asciz "Read error\n\r"
msg_err_no_file:	.asciz "Loader not found\n\r"
err_disk:		err msg_err_disk
err_no_file:		err msg_err_no_file


/*
* End of sector
*/

signature:
	. = _start + 0x1FE	// 512 bytes - signature length
	.word 0xAA55		// boot signature
