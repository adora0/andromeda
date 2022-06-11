	/*
	 * Kernel loader
	 */	
	

	.code16

	.section .text

	.global _start

	.global	read_sectors_32	

	.extern load_kernel


#include "loaddefs.h"


	/*
	 * Stack pointer loaded by boot sector
	 */

	.set STACK_TOP,			0x1500
	

	/*
	 * Address of loaded boot sector and disk parameter offsets
	 */

	.set BOOT_ADDR,			0x7C00
	.set BOOT_OFFSET_BPB,		0x03
	.set BOOT_OFFSET_GEOM,	        0x3E


	/*
	 * Address to load the root directory and FAT
	 * 4KiB above loader
	 * Loader starts at 0x9E00
	 */

	.set DATA_ADDR,			0xAE00


	/*
	 * Address to load temporary kernel data
	 */

	.set LOAD_ADDR,			0xBE00


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
	jnc	read_root		// skip if A20 already enabled


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
	jnc	read_root


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
	jnc	read_root


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
	jnc	read_root


a20_failed:
	
	/* All A20 enable methods failed */

	popf

	jmp	err_a20


read_root:

	/* Read root directory */


	/* Set destination */

	xor 	%ax, %ax
	mov 	%ax, %es		// clear segment
	mov 	$DATA_ADDR, %di		// set offset


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


	/* Read */

	clc
	call	read_sectors		// read sectors


	/* Restore registers */

	pop	%di
	pop 	%es


	jc 	err_disk		// fail

	movw 	%bx, disk_data_sector	// store first data sector


find_file:

	/* Find kernel loader in root directory at location ES:DI */


	xor 	%ax, %ax
	mov 	%ax, %es		// clear root directory segment
	mov	$DATA_ADDR, %di		// set root directory offset
	mov 	%ax, %dx		// clear filename segment
	lea 	filename, %si		// set filename offset


	/* Get size of root directory */

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


3:	jc 	err_no_file		// fail

	movw 	%bx, first_file_cluster	// store first cluster


read_fat:

	/* Read the FAT into location ES:DI */

	xor 	%ax, %ax
	mov 	%ax, %es		// clear FAT segment
	mov	$DATA_ADDR, %di		// set FAT offset


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
	call	read_sectors


	/* Restore registers */
	
	pop	%di
	pop 	%es


	jc	err_disk		// fail



	/* Call 32-bit protected mode C function to load kernel */


	call	switch_protected


	.code32	

	
	mov	$LOAD_ADDR, %eax
	mov	$DATA_ADDR, %edx
	xor	%ecx, %ecx
	movw	first_file_cluster, %cx
	call	load_kernel

	cmp	$0, %eax
	jl	load_failed


start_kernel:

	/* Start kernel execution */

	jmp	*%eax


_end32:

	/* Halt execution */

	cli
1:	hlt
	jmp	1b



load_failed:

	/* Failed to load kernel */

	movw	%ax, reg_save_ax

	call	switch_real


	.code16


	movw	reg_save_ax, %ax

	cmp	$ERRNO_MULTIBOOT, %ax
	je	err_multiboot

	cmp	$ERRNO_ELF, %ax
	je	err_elf

	jmp	err_kernel


_end16:

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


/*
 * Read sectors from disk
 *	in:	AX = LBA
 *		DX = number of sectors
 *		ECX -> buffer
 *
 *	out:	data at buffer
 *		EAX = -1 on error
 *		EAX -> end of read buffer
 */
	
	.code32

read_sectors_32:

	/* Save arguments */

	movw	%ax, reg_save_ax	// LBA
	movw	%dx, reg_save_cx	// number of sectors

        movw    %cx, reg_save_di	// offset
        xor     %cx, %cx
        shr     $20, %ecx               // upper 15 bits
        movw    %cx, reg_save_es	// segment


	call	switch_real


	.code16


	/* Restore arguments */

	movw	reg_save_ax, %ax
	movw	reg_save_cx, %cx
	movw	reg_save_es, %es
	movw	reg_save_di, %di


	/* Read */

	call	read_sectors

	jc	1f			// fail


	/* Save buffer address */

	movw	$0, reg_save_eax
	movw	%es, reg_save_es
	movw	%di, reg_save_di

	jmp	2f


1:	/* Fail */

	movl	$-1, reg_save_eax


2:	/* Return */

	call	switch_protected


	.code32


	movl	reg_save_eax, %eax

	cmp	$-1, %eax
	je	3f			// return immediately on fail


	/* Convert buffer to physical address */

	xor	%eax, %eax
	movw	reg_save_es, %ax
	movl	$0x10, %ebx
	mull	%ebx			// convert segment
	addw	reg_save_di, %ax	// add offset


3:	ret


	.code16


/*
 * Switch to 32-bit protected mode
 */

switch_protected:

	/* Disable maskable interrupts */

	cli


	/* Disable non-maskable interrupts */

	in	$0x70, %ax		// CMOS RAM Index register
	or	$0x80, %ax		// mask bits 0-6
	out	%ax, $0x70

	in	$0x71, %ax		// wait for CMOS


	/* Load 32-bit GDT */

	lgdt	gdt_32


	/* Set Control Register 0 */

	mov     %cr0, %eax
        or      $1, %al			// set PE bit
        mov     %eax, %cr0

	
	/* Perform far jump to set code segment (1st descriptor) */

        ljmp	$0x08, $_protected_entry_32


_protected_entry_32:
	

	.code32
	

	/* Load segment registers */

	mov     $0x10, %eax		// select data segment (2nd descriptor)
        mov     %eax, %ds
        mov     %eax, %es
        mov     %eax, %fs
        mov     %eax, %gs
        mov     %eax, %ss	


	ret



/*
 * Switch to 16-bit real mode
 * (Assumes paging is already disabled, the default state
 *  upon reset of the CPU)
 */

switch_real:

	/* Disable maskable interrupts */

	cli


	/* Disable non-maskable interrupts */

	in	$0x70, %eax		// CMOS RAM Index register
	or	$0x80, %eax		// mask bits 0-6
	out	%eax, $0x70

	in	$0x71, %eax		// wait for CMOS


	/* Store return address */

	push	%ebp
	mov	%esp, %ebp
	mov	4(%ebp), %ebp
	movw	%bp, real_return
	pop	%ebp

	
	/* Load 16-bit GDT */

	lgdt	gdt_16


	/* Perform far jump to set code segment (1st descriptor) */

        ljmp	$0x08, $_protected_entry_16


_protected_entry_16:


	.code16


	/* Load segment registers */

	mov     $0x10, %ax		// select data segment (2nd descriptor)
        mov     %ax, %ds
        mov     %ax, %es
        mov     %ax, %fs
        mov     %ax, %gs
        mov     %ax, %ss

	
	/* Load 16-bit IDT */

	lidt	idt_16


	/* Disable protected mode */

	mov	%cr0, %eax
	and	$0xFFFFFFFE, %eax	// clear PE bit
	mov	%eax, %cr0


	/* Perform far jump to reset code segment to 0 */

        ljmp	$0, $_real_entry


_real_entry:

	/* Load registers */

	xor	%ax, %ax		// reset segment registers to 0
	mov     %ax, %ds
        mov     %ax, %es
        mov     %ax, %fs
        mov     %ax, %gs
        mov     %ax, %ss
	mov	$STACK_TOP, %sp		// set stack pointer
	

	/* Enable non-maskable interrupts */

	in	$0x70, %ax		// CMOS RAM Index register
	and	$0x7F, %ax		// set bit 7
	out	%ax, $0x70


	/* Enable maskable interrupts */

	sti

	
	/* Explicit return to callee */
	
	pushw	real_return

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
first_file_cluster:	.word	0
disk_data_sector:	.word	0

disk_geom_end:


/*
 * Flat 4GiB 32-bit GDT
 */

gdt_32:

        .word   gdt_32_end - gdt_32_start - 1	// last byte in table
	.long	gdt_32_start			// start of table

gdt_32_start:

	/*
	 * Null descriptor
	 *	Base = 0
	 *	Limit = 0x00000000
	 *	Access Byte = 0x00
	 *	Flags = 0x0
	 */

	.quad	0


	/*
	 * Ring 0 code segment
	 *	Base = 0
	 *	Limit = 0xFFFFF
	 *	Access Byte = 0x9A
	 *	Flags = 0xC
	 */

	.quad	0x00CF9A000000FFFF


	/*
	 * Ring 0 data segment
	 *	Base = 0
	 *	Limit = 0xFFFFF
	 *	Access Byte = 0x92
	 *	Flags = 0xC
	 */

	 .quad	0x00CF92000000FFFF


gdt_32_end:


/*
 * Flat 4GiB 16-bit GDT
 */

gdt_16:

        .word   gdt_16_end - gdt_16_start - 1	// last byte in table
	.long	gdt_16_start			// start of table

gdt_16_start:

	/*
	 * Null descriptor
	 *	Base = 0
	 *	Limit = 0x00000000
	 *	Access Byte = 0x00
	 *	Flags = 0x0
	 */

	.quad	0


	/*
	 * Ring 0 code segment
	 *	Base = 0
	 *	Limit = 0xFFFF
	 *	Access Byte = 0x9A
	 *	Flags = 0xC
	 */

	.quad	0x00809A000000FFFF


	/*
	 * Ring 0 data segment
	 *	Base = 0
	 *	Limit = 0xFFFF
	 *	Access Byte = 0x92
	 *	Flags = 0xC
	 */

	 .quad	0x008092000000FFFF


gdt_16_end:


/*
 * 16-bit IDT
 */

idt_16:

	.word	0x3FF	// 256 entries, 4b each = 1K
	.long	0	// Real Mode IVT @ 0x0000


/*
 * Callee return address for real mode switch
 */

real_return:
	
	.word	0


/*
 * Register storage space for mode switching
 */

reg_save_ax:		.word 0
reg_save_cx:		.word 0
reg_save_di:		.word 0
reg_save_es:		.word 0
reg_save_eax:		.long 0

/*
 * Kernel filename
 * 11 bytes with no null termination
 */

filename:		.ascii  "KERNEL  ELF"


/* Messages */

	.macro m_err str
	leaw	\str, %si
	call	puts
	jmp	_end16
	.endm

msg_load:		.asciz "Starting Andromeda...\n\r"
msg_err_a20:		.asciz "Failed to enable A20 line\n\r"
msg_err_disk:		.asciz "Disk read error\n\r"
msg_err_no_file:	.asciz "Kernel not found\n\r"
msg_err_multiboot:	.asciz "Missing or invalid multiboot header\n\r"
msg_err_elf:		.asciz "Failed to parse kernel ELF\n\r"
msg_err_kernel:		.asciz "Failed to load kernel\n\r"

err_a20:		m_err msg_err_a20
err_disk:		m_err msg_err_disk
err_no_file:		m_err msg_err_no_file
err_multiboot:		m_err msg_err_multiboot
err_elf:		m_err msg_err_elf
err_kernel:		m_err msg_err_kernel
