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
	.set BPB_SIZE,		26

	/*
	* Disk geometry relative address
	*/
	.set GEOMETRY_OFFSET,	0x3E
	.set GEOMETRY_SIZE,	5

	/*
	* After the A20 gate has been enabled,
	* addresses after 1MiB +64KiB are moved to a buffer
	* before copying to the final destination due to BIOS limitations.
	* NOTE: 4KiB above code, modify as required
	*/
	.set BUFFER_ADDR,	0xAE00

	/*
	* Offset address to load the root directory and FAT
	*/
	.set DATA_ADDR,		0xBE00

	/*
	* Offset address to load the kernel binary
	*/
	.set LOAD_ADDR,		0x100000	// 1MiB

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
	ljmp	$0, $1f			// reset code segment
1:	/* Print loader message */
	lea	msg_load, %si
	call	puts

	push	%ds			// save segment

	/* Copy BIOS parameter block */
	xor	%ax, %ax
	mov	%ax, %es		// destination segment
	lea	bpb_start, %di		// destination offset
	mov	$(BOOT_ADDR >> 4), %ax
	mov	%ax, %ds		// effective source segment
	mov	$BPB_OFFSET, %si	// source offset
	mov	$BPB_SIZE, %cx		// size
rep	movsb				// copy from DS:SI to ES:DI

	/* Copy disk geometry */
	xor	%ax, %ax
	mov	%ax, %es		// destination segment
	lea	disk_start, %di		// destination offset
	mov	$(BOOT_ADDR >> 4), %ax
	mov	%ax, %ds		// effective source segment
	mov	$GEOMETRY_OFFSET, %si	// source offset
	mov	$GEOMETRY_SIZE, %cx	// size
rep	movsb				// copy from DS:SI to ES:DI

	pop	%ds			// restore segment

enable_a20:
	/* Enable the A20 line to address memory above 1MiB +64KiB */
	call	3f
	
	call	enable_a20_bios
	jc	1f			// next method
	call	3f

1:	call	enable_a20_8042
	call	3f

2:	call	enable_a20_fast
	jc	err_a20			// all methods failed
	call	3f	

3:	/* Check */
	call	check_a20
	jnc	a20_enabled		// continue if enabled
	ret

a20_enabled:
	/*
	* Read kernel into memory
	*/

	/* Read root directory */
	xor 	%ax, %ax
	mov 	%ax, %es		// clear destination segment
	mov 	$DATA_ADDR, %di		// set destination offset
	call 	load_root		// read
	jc 	err_disk
	movw 	%bx, disk_data_sector	// store first data sector

	/* Find kernel in root directory at ES:DI */
	xor	%dx, %dx		// clear filename segment
	lea 	filename, %si		// set filename offset
	call 	find_file		// find
	jc 	err_no_file
	movw 	%bx, disk_cluster	// store first cluster

	/* Load the FAT at ES:DI in order to find the required clusters */
	call 	load_fat

	/* Read file clusters */
	// mov 	%es, %dx		// segment of FAT
	// mov 	%di, %si		// offset of FAT
	// xor 	%ax, %ax
	// mov 	%ax, %es		// destination segment
	// mov 	$LOAD_ADDR, %di		// destination offset
	// movw 	disk_cluster, %ax	// first cluster
	// call	load_file		// read
	// jmp 	err_disk

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
* Kernel filename
* 11 chars with no null termination
*/
filename:		.ascii  "KERNEL  ELF"

/*
* Messages
*/

	.macro err str
	leaw	\str, %si
	call	puts
	jmp	_end
	.endm

msg_load:		.asciz "Loading...\n\r"
msg_err_a20:		.asciz "Failed to enable A20 line\n\r"
msg_err_disk:		.asciz "Read error\n\r"
msg_err_no_file:	.asciz "Kernel not found\n\r"
err_a20:		err msg_err_a20
err_disk:		err msg_err_disk
err_no_file:		err msg_err_no_file

/*
* Includes
*/
	.include "vga.S"
	.include "a20.S"
	.include "disk.S"
