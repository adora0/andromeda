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
	.set BOOT_OFFSET_SHARED,	0x43


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
	call	*puts


load_parameters:

	/* Load disk parameters from boot sector in memory */

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
	jnc	enable_unreal		// skip if A20 already enabled


enable_a20_bios:

	/* Enable via BIOS */

	/* Int 0x15/AH=0x2403: SYSTEM - later PS/2s - QUERY A20 GATE SUPPORT */

	mov	$0x2403, %ax
	int	$0x15
	jc	enable_a20_8042		// not supported
	cmp	$0, %ah
	jnz	1f
	

	/* Int 0x15/AH=0x2402: SYSTEM - later PS/2s - GET A20 GATE STATUS */

	mov	$0x2402, %ax
	int	$0x15
	jc	enable_a20_8042		// failed: unable to get status
	cmp	$0, %ah
	jnz	1f
	
	cmp	$1, %al
	jz	1f			// already activated
	

	/* Int 0x15/AH=0x2401: SYSTEM - later PS/2s - ENABLE A20 GATE */

	mov	$0x2401, %ax
	int	$0x15

	jc	enable_a20_8042		// failed

	cmp	$0, %ah
	jnz	enable_a20_8042		// failed


1:	call	check_a20		// success: check

	jnc	enable_unreal


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

	jnc	enable_unreal


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

	call	check_a20	// success: check
	
	jnc	enable_unreal


a20_failed:
	
	/* All A20 enable methods failed */

	popf
	jc	err_a20



enable_unreal:

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


	/* TODO:
	 * Read root directory
	 * Find first sector of kernel
	 * Read FAT
	 * Read and relocate ELF
	 * Enable protected mode
	 * Start kernel execution
	 */


_end:

	/* Halt execution */

	cli
1:	hlt
	jmp 1b



/***************
* Functions
***************/


	/*
	 * Define external shared symbol location
	 */
	
	.macro m_shared name, offset
	.set \name, BOOT_ADDR + BOOT_OFFSET_SHARED + \offset
	.endm


/*
 * Output a null-terminated string in text mode
 *	in:	SI -> string
 */

m_shared	puts, 0


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

m_shared	read_sectors, 8


/*
 * Check the status of the A20 line
 *	out:	CF set if disabled
 */

check_a20:

	push	%ds
	pushf			// save flags to restore interrupts
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

	popf			// restore flags
	stc			// fail

	ret


1:	/* A20 enabled if memory does not wrap around */

	popf			// restore flags

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
	call	*puts
	jmp	_end
	.endm

msg_load:		.asciz "Loading...\n\r"
msg_err_a20:		.asciz "Failed to enable A20 line\n\r"
msg_err_disk:		.asciz "Disk read error\n\r"
err_a20:		m_err msg_err_a20
err_disk:		m_err msg_err_disk
