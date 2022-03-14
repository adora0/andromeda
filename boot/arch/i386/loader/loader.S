	/*
	* Kernel loader
	* Switch to protected mode and load kernel
	*/	
	
	.code16

	.section .text
	.global _start


	.global exit
	.global puts
	.extern load_elf


	/*
	* Address of loaded boot sector and parameter offsets
	*/

	.set BOOT_ADDR,			0x7C00
	.set BOOT_BPB_OFFSET,		0x03
	.set BOOT_DISK_GEOM_OFFSET,	0x03E


_start:
	ljmp	$0, $1f			// reset code segment


1:	/* Print loader message */

	lea	msg_load, %si
	push	%si

	call	puts
	
	pop	%si


	/* Load parameters from boot sector */

	xor	%ax, %ax
	mov	%ax, %ds
	mov	%ax, %es

	mov	$(BOOT_ADDR + BOOT_BPB_OFFSET), %si 		// source
	lea	bpb_start, %di					// destination

	lea	bpb_end, %cx
	sub	%di, %cx		// size in bytes

rep	movsb				// copy

	mov	$(BOOT_ADDR + BOOT_DISK_GEOM_OFFSET), %si	// source
	lea	disk_geom_start, %di				// destination

	lea	disk_geom_end, %cx
	sub	%di, %cx		// size in bytes

rep	movsb				// copy


enable_a20:
	/* Enable the A20 line to address memory above 1MiB +64KiB */

	call	3f

	/* BIOS */
	
	call	enable_a20_bios
	jc	1f			// next method
	call	3f


1:	/* 8042 */

	call	enable_a20_8042
	call	3f


2:	/* Fast A20 */

	call	enable_a20_fast
	jc	err_a20			// all methods failed
	call	3f	


3:	/* Check */

	call	check_a20
	jnc	a20_enabled		// continue if enabled

	ret


a20_enabled:
	/* Switch to unreal mode */

	call	enable_unreal


	/* Load kernel */

	call	load_elf


	/* Switch to protected mode */
	
	call	enable_protected


	.code32


	/* Load segment registers */

	mov     $0x08, %ax		// select descriptor 1 (0b1000)
        mov     %ax, %ds
        mov     %ax, %es
        mov     %ax, %fs
        mov     %ax, %gs
        mov     %ax, %ss


	/* TODO: Start kernel */

/*
* Halt execution
*/

_end:
	cli
1:	hlt
	jmp 1b
	

	.code16


/***************
* Functions
***************/


/*
* Exit loader
*/

exit:
	jmp	_end


/*
* Output a null-terminated string in text mode
*	in:	%sp+2 -> string
*/

puts:
	movw	2(%esp), %si
	
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
* Check status of the A20 address line
*	out:	CF = 0 if enabled
*		CF = 1 if disabled
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
	stc			// set CF if memory does wrap around
	jmp	2f


1:	/* A20 enabled if memory does not wrap around */

	popf			// restore flags
	clc			// clear CF if memory does not wrap around


2:	pop	%ds
	ret


/*
* Enable the A20 line via the BIOS (PS/2 and later specific models)
*	out:	CF = 0 on success
*		CF = 1 on failure
*/

enable_a20_bios:
	/*
	* Int 0x15/AH=0x2403: SYSTEM - later PS/2s - QUERY A20 GATE SUPPORT
	*/

	mov	$0x2403, %ax
	int	$0x15
	jc	2f		// not supported
	cmp	$0, %ah
	jnz	1f
	

	/*
	* Int 0x15/AH=0x2402: SYSTEM - later PS/2s - GET A20 GATE STATUS
	*/

	mov	$0x2402, %ax
	int	$0x15
	jc	2f		// unable to get status
	cmp	$0, %ah
	jnz	1f
	
	cmp	$1, %al
	jz	2f		// already activated
	

	/*
	* Int 0x15/AH=0x2401: SYSTEM - later PS/2s - ENABLE A20 GATE
	*/

	mov	$0x2401, %ax
	int	$0x15
	jc	2f		// failed to enable
	cmp	$0, %ah
	jnz	1f
	
	jmp	2f		// success


1:	stc			// set CF on failure
2:	ret


/*
* Enable the A20 line via the 8042 keyboard controller
*/

enable_a20_8042:
	pushf
	cli

	call	1f		// wait for input buffer
	mov	$0xAD, %al	// disable keyboard
	out	%al, $0x64	// send command

	call	1f		// wait for input buffer
	mov	$0xD0, %al	// read input
	out	%al, $0x64	// send command
	
	call	2f		// wait for output buffer
	in	$0x60, %al	// read input buffer from output port
	push	%ax

	call	1f		// wait for input buffer
	mov	$0xD1, %al	// write to output
	out	%al, $0x64	// send command

	call	1f		// wait for input buffer
	pop	%ax
	
	or	$2, %al		// enable bit 1 (A20)
	out	%al, $0x60	// write to output port

	call	1f		// wait for input buffer
	mov	$0xAE, %al	// enable keyboard
	out	%al, $0x64	// send command

	call	1f
	jmp	3f


1:	/* Wait for input buffer */

	in	$0x64, %al
	test	$2, %al		// bit 1 (input buffer status)
	jnz	1b		// zero when ready
	ret


2:	/* Wait for output buffer */

	in	$0x64, %al
	test	$1, %al		// bit 0 (output buffer status)
	jz	2b		// non-zero when ready
	ret


3:	popf
	ret


/*
* Enable the A20 line via the Fast A20 port (PS/2 and later)
*	out:	CF = 0 if supported
*		CF = 1 on failure
*/

enable_a20_fast:
	pushf
	cli			// disable interrupts

	in	$0x92, %al
	test	$2, %al
	jnz	1f		// unsupported
	or	$2, %al		// set bit 1 for Fast A20
	and	$0xFE, %al	// do not write to bit 0
	out	%al, $0x92	// write

	clc
	jmp	2f


1:	popf
	stc

2:	ret


/*
* Enable protected mode
*/

enable_protected:
	cli

	lgdt	gdt_info	// load GDT register

	mov     %cr0, %eax
        or      $1, %al
        mov     %eax, %cr0	// set first bit in control register 0

        jmp     . + 2		// prevent crash on 386/486

	ret


/*
* Enable unreal mode
*/

enable_unreal:
	cli

	push	%ds			// save real mode
	
	call	enable_protected	// protected mode

	mov	$8, %bx			// select descriptor 1 (1000b)
	mov	%bx, %ds

	and	$0xFE, %al		// return to real mode
	mov	%eax, %cr0		// toggle bit in cr0

	pop	%ds			// restore real mode segment

	sti

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
* Messages
*/

	.macro err str

	leaw	\str, %si
	push	%si
	call	puts
	jmp	_end

	.endm

msg_load:		.asciz "Loading...\n\r"
msg_err_a20:		.asciz "Failed to enable A20 line\n\r"
err_a20:		err msg_err_a20
