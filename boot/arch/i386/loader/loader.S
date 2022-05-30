	/*
	 * Kernel loader
	 */	
	

	.code16

	.section .text
	.global _start


	/*
	 * Address of loaded boot sector and disk parameter offsets
	 */

	.set BOOT_ADDR,			0x7C00
	.set BOOT_OFFSET_BPB,		0x03
	.set BOOT_OFFSET_GEOM,	        0x3E


	/*
	 * Address to load the root directory and FAT
	 * Conventional memory space 0x7E00-0x7FFFF
	 * 4KiB space before kernel buffer
	 * Loader starts at 0x9E00
	 */

	.set DATA_ADDR,			0xFE00


_start:
	ljmp	$0, $1f		// reset code segment

1:

	/* Print loader message */

	lea	msg_load, %si
	call	puts


load_parameters:

	/* Load disk parameters from boot sector loaded into memory */

        xor	%ax, %ax                // reset segments
	mov	%ax, %ds
	mov	%ax, %es

	mov	$(BOOT_ADDR + BOOT_OFFSET_BPB), %si 	// source
	lea	bpb_start, %di				// destination

	lea	bpb_end, %cx
	sub	%di, %cx		// size in bytes

rep	movsb				// copy

	mov	$(BOOT_ADDR + BOOT_OFFSET_GEOM), %si	// source
	lea	disk_geom_start, %di			// destination

	lea	disk_geom_end, %cx
	sub	%di, %cx		// size in bytes

rep	movsb				// copy


enable_a20:

	/* Enable the A20 line to address memory above 1MiB +64KiB */

	call	check_a20
	jnc	a20_enabled		// skip if A20 already enabled


enable_a20_bios:

	/* Enable via BIOS */

	/* Int 0x15/AH=0x2403: SYSTEM - later PS/2s - QUERY A20 GATE SUPPORT */

	mov	$0x2403, %ax
	int	$0x15
	jc	enable_a20_8042		// not supported
	cmp	$0, %ah
	jz	enable_a20_8042		// not supported
	

	/* Int 0x15/AH=0x2402: SYSTEM - later PS/2s - GET A20 GATE STATUS */

	mov	$0x2402, %ax
	int	$0x15
	jc	enable_a20_8042		// unable to get status
	cmp	$0, %ah
	jnz	enable_a20_8042		// unable to get status
	
	cmp	$1, %al
	jz	1f			// already activated
	

	/* Int 0x15/AH=0x2401: SYSTEM - later PS/2s - ENABLE A20 GATE */

	mov	$0x2401, %ax
	int	$0x15

	jc	enable_a20_8042		// failed

	cmp	$0, %ah
	jnz	enable_a20_8042		// failed


1:	call	check_a20		// success - check
	jnc	a20_enabled


enable_a20_8042:

	/* Enable via 8042 keyboard controller */

	pushf
	cli

	call	wait_8042_in
	mov	$0xAD, %al	// disable keyboard
	out	%al, $0x64	// send command

	call	wait_8042_in
	mov	$0xD0, %al	// read input
	out	%al, $0x64	// send command
	
	call	wait_8042_out
	in	$0x60, %al	// read input buffer from output port
	push	%ax

	call	wait_8042_in
	mov	$0xD1, %al	// write to output
	out	%al, $0x64	// send command

	call	wait_8042_in
	pop	%ax
	
	or	$2, %al		// enable bit 1 (A20)
	out	%al, $0x60	// write to output port

	call	wait_8042_in
	mov	$0xAE, %al	// enable keyboard
	out	%al, $0x64	// send command

	jmp	check_a20_8042


wait_8042_in:

	/* Wait for input buffer */

	in	$0x64, %al
	test	$2, %al		// bit 1 (input buffer status)
	jnz	wait_8042_in	// zero when ready

	ret


wait_8042_out:

	/* Wait for output buffer */

	in	$0x64, %al
	test	$1, %al		// bit 0 (output buffer status)
	jz	wait_8042_out	// non-zero when ready

	ret


check_a20_8042:
	
	popf

	call	check_a20
	jnc	a20_enabled


enable_a20_fast:

	/* Enable A20 via the Fast A20 port (PS/2 and later) */

	pushf
	cli			// disable interrupts

	in	$0x92, %al
	test	$2, %al
	jnz	a20_failed	// unsupported
	or	$2, %al		// set bit 1 for Fast A20
	and	$0xFE, %al	// do not write to bit 0
	out	%al, $0x92	// write

	call	check_a20	// success - check
	jnc	a20_enabled


a20_failed:
	
	/* All A20 enable methods failed */

	popf

	jmp	err_a20


a20_enabled:

	/* Enable unreal mode */

	pushf
	cli

	push	%ds			// save real mode segment
	

	lgdt	gdt_info		// load GDT register

	mov     %cr0, %eax
        or      $1, %al
        mov     %eax, %cr0		// set first bit in cr0

        jmp     . + 2			// prevent crash on 386/486


	mov	$8, %bx			// select descriptor 1 (1000b)
	mov	%bx, %ds


	and	$0xFE, %al
	mov	%eax, %cr0		// set real mode bit in cr0


	pop	%ds			// restore real mode segment

	popf


	/* FIXME: Read root directory into location ES:DI */

	xor	%ax, %ax
	mov	%ax, %es		// clear segment
	mov	$DATA_ADDR, %di		// set offset

	call	read_root
	jc	err_disk		// fail

	
	/* Find kernel and save index of first cluster in BX */

	xor	%dx, %dx		// clear filename segment
	lea	filename, %si		// set filename offset

	call	find_file
	jc	err_no_file		// fail


	/* Read FAT into location ES:DI */

	call	read_fat
	jc	err_disk		// fail


	/* TODO: Read and relocate ELF */

	/* TODO: Enable protected mode */

	/* TODO: Start kernel execution */


_end:

	/* Halt execution */

	cli
1:	hlt
	jmp	1b



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
 * Check the status of the A20 line
 *	out:	CF set if disabled
 */

check_a20:

	push	%ax
	push	%es
	push	%ds
	push	%di
	push	%si

	pushf
	cli			// clear interrupts


	xor	%ax, %ax
	mov	%ax, %es	// ES = 0

	not	%ax
	mov	%ax, %ds	// DS = 0xFFFF

	mov	$0x0500, %di
	mov	$0x0510, %si

	mov	%es:(%di), %al		// read 0x0000:0x0500
	push	%ax
	
	mov	%ds:(%si), %al		// read 0xFFFF:0x0510
	push	%ax

	movb	$0x00, %es:(%di)	// clear 0x0000:0x0500
	movb	$0xFF, %ds:(%si)	// set 0xFFFF:0x0500 to 0xFF

	cmpb	$0xFF, %es:(%di)	// check 0x0000:0x0500
	
	pop	%ax
	mov	%al, %ds:(%si)		// restore byte

	pop	%ax
	mov	%al, %es:(%di)		// restore byte


	jne	1f		// 0x0000:0x0500 was not set: memory does not wrap around


	/* A20 disabled if memory wraps around */
	
	popf
	stc			// fail
	jmp	2f

	ret


1:	/* A20 enabled if memory does not wrap around */

	popf
	clc			// success


2:	pop	%si
	pop	%di
	pop	%ds
	pop	%es
	pop	%ax

	ret


/*
 * Read FAT12/16 root directory
 *	in:	ES:DI -> buffer
 *
 *	out:	data at ES:DI
 *              BX = first data sector
 *		CF set on error
 */

read_root:

	push	%ax
	push	%cx


	/* Store size in CX */

	mov	$32, %ax		// root entry size
	mulw	bpb_root_entries	// * number of entries
	divw	bpb_sector_size		// / sector size
	mov	%ax, %cx		// number of sectors


	/*
	 * Store location in AX
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
	call	read_sectors		// read sectors


	/* Restore registers */

	pop	%di
	pop 	%es


	pop	%cx
	pop	%ax


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


3:	ret


/*
 * Read file allocation table
 *	in:	ES:DI -> buffer
 *
 *	out:	data in ES:DI
 *		CF set on error
 */

read_fat:

	/* Calculate size of FAT and store in CX */
	
	movw	bpb_sectors_fat, %ax	// sectors per FAT
	mulb	bpb_fat_count		// * number of FATs
	mov	%ax, %cx


	/* Save location in AX */
	
	movw	bpb_reserved_sectors, %ax


	/* Save registers */
	
	push	%es
	push 	%di


	/* Read FAT into buffer */
	
	clc
	call	read_sectors


	/* Restore registers */
	
	pop	%di
	pop 	%es


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

read_sectors:

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


4:	pop    %si
        pop    %dx
        pop    %cx
        pop    %bx
        pop    %ax
	ret


/**************/



/*
 * FAT12/16 BIOS parameter block (BPB)
 * Parameters set in boot sector
 */

bpb_start:

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

bpb_end:


/*
 * Disk geometry
 * Parameters set in boot sector
 */

disk_geom_start:

drive_number:		.byte	0
disk_cluster:		.word	0
disk_data_sector:	.word	0

disk_geom_end:


/*
* Global Descriptor Table
* Flat 4GiB with no address translation
*/

gdt_info:

        .word   gdt_end - gdt_start - 1	// last byte in table
	.long	gdt_start		// start of table

gdt_start:
	/* Null descriptor */

	.long	0
	.long	0


	/* Code descriptor */

	.word	0xFFFF		// segment limit (bits 0-16)
	.word	0		// base address (bits 0-16)
	.byte	0		// base address (bits 16-23)
	.byte	0b10010010	// type, privilege level, present flag
	.byte	0b11001111	// segment limit (bits 16-19), attributes, granularity
	.byte	0		// base address (bits 24-31)

gdt_end:


/*
 * Kernel filename
 * 11 bytes with no null termination
 */

filename:		.ascii  "KERNEL  ELF"


/* Messages */

	.macro m_err str
	leaw	\str, %si
	call	puts
	jmp	_end
	.endm

msg_load:		.asciz "Starting Andromeda\n\r"
msg_err_a20:		.asciz "Failed to enable A20 line\n\r"
msg_err_disk:		.asciz "Disk read error\n\r"
msg_err_no_file:	.asciz "Kernel not found\n\r"
err_a20:		m_err msg_err_a20
err_disk:		m_err msg_err_disk
err_no_file:		m_err msg_err_no_file
