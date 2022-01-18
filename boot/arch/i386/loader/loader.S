	/*
	* Kernel loader
	* Switch to protected mode and load kernel
	*/	
	
	.code16
	.section .text
	.global _start

	/*
	* Address of loaded boot sector
	*/
	.set BOOT_ADDR,		0x7C00

	/*
	* BIOS parameter block relative address
	*/
	.set BPB_OFFSET,	0x03
	.set BPB_SIZE,		33

	/*
	* Disk geometry relative address
	*/
	.set GEOMETRY_OFFSET,	0x3E
	.set GEOMETRY_SIZE,	5

	/*
	* After the A20 gate has been enabled,
	* addresses after 1MiB +64KiB are moved to a buffer
	* before copying to the final destination due to BIOS limitations.
	*/
	.set BUFFER_ADDR,	0xA000		// located 4KiB after loader start

	/*
	* Offset address to load the root directory and FAT
	* Located after loader at 0x9000
	*/
	.set DATA_ADDR,		0xB000		// located 4KiB after load buffer

	/*
	* Offset address to load the kernel binary
	* Located after buffer (must have sufficient space for the root directory)
	*/
	.set LOAD_ADDR,		0x100000	// located at 64KiB

/*
* FAT12/16 BIOS parameter block (BPB)
* Copied from boot sector
*/
bpb_start:
bpb_oem_id:		.space	8, 0
bpb_sector_size:	.word	0
bpb_sectors_cluster:	.byte	0
bpb_reserved_sectors:	.word	0
bpb_fat_count:		.byte	0
bpb_root_entries:	.word	0
bpb_sector_count:	.word	0
bpb_media_type:		.byte	0
bpb_sectors_fat:	.word	0
bpb_sectors_track:	.word	0
bpb_head_count:		.word	0
bpb_hidden_sectors:	.long	0
bpb_large_sectors:	.long	0

/*
* Disk geometry space
* Copied from boot sector
*/
disk_start:
drive_number:		.byte	0
disk_cluster:		.word	0
disk_data_sector:	.word	0

_start:
	lea	msg_load, %si		// loader message
	call	puts

	push	%ds			// save segment

	/* Copy BIOS parameter block */
	xor	%ax, %ax
	mov	%ax, %es
	lea	bpb_start, %di		// destination
	mov	$BOOT_ADDR, %ax
	mov	%ax, %ds		// source segment
	mov	$BPB_OFFSET, %si	// source offset
	mov	$BPB_SIZE, %cx		// size
rep	movsb				// copy byte from DS:SI to ES:DI

	/* Copy disk geometry */
	lea	disk_start, %di		// destination
	mov	$GEOMETRY_OFFSET, %si	// source offset
	mov	$GEOMETRY_SIZE, %cx	// size
rep	movsb				// copy byte from DS:SI to ES:DI

	pop	%ds			// restore segment

enable_a20:
	/* Enable the A20 line to address memory above 1MiB +64KiB */
	call	4f
	
	call	enable_a20_bios
	jc	1f
	call	4f

1:	call	enable_a20_8042
	call	4f

2:	call	enable_a20_fast
	jc	err_a20
	call	4f

3:	jmp	err_a20			// all methods failed

4:	/* Check */
	call	check_a20
	jnc	a20_enabled		// continue if enabled
	ret

a20_enabled:
	/* Read the kernel into memory */

	/* Load the Global Descriptor Table (GDT) */

	/* Disable interrupts and switch to protected mode */

	/* Execute the kernel */

/*
* Halt execution
*/
_end:
	cli
1:	hlt
	jmp 1b

/*
* Log messages
*/

	.macro err str
	leaw	\str, %si
	call	puts
	jmp	_end
	.endm

err_a20:		err msg_err_a20
msg_err_a20:		.asciz "Failed to enable A20 line\n\r"

/*
* Includes
*/
	.include "vga.S"
	.include "a20.S"

/*
* Messages
*/
msg_load:		.asciz "Loading...\n\r"

/*
* Kernel filename
* 11 chars with no null termination
*/
filename:		.ascii  "KERNEL  ELF"
