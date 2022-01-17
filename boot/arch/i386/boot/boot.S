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

	/* Offset address of >1KiB stack top before boot code */
	.set STACK_TOP,		0x7000

	/*
	* Offset address to load the root directory and FAT
	* Located after boot code at 0x7C00
	*/
	.set DATA_ADDR,		0x8000

	/*
	* Offset address to load the loader binary
	* Located after buffer (must have sufficient space for the root directory)
	*/
	.set LOAD_ADDR,		0x9000

_start:
	/*
	* E9 (..) 90 opcodes required by BIOS parameter block
	* jmp short, nop
	*/
	jmp	main
	nop

/*
* FAT12/16 BIOS parameter block (BPB)
* Parameters set by format tools
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
* Disk geometry space
*/
	. = _start + 0x03E
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
	movw	$STACK_TOP, %sp		// set stack top

	movb	%dl, drive_number	// save drive number set by BIOS
	
	sti			// restore interrupts
	
	/*
	* Read root directory
	*/
	xor 	%ax, %ax
	mov 	%ax, %es		// clear destination segment
	mov 	$DATA_ADDR, %di		// set destination offset
	call 	load_root		// read
	jc 	err_disk
	movw 	%bx, disk_data_sector	// store first data sector

	/*
	* Find kernel loader in root directory at ES:DI
	*/
	xor	%dx, %dx		// clear filename segment
	lea 	filename, %si		// set filename offset
	call 	find_file		// find
	jc 	err_no_file
	movw 	%bx, disk_cluster	// store first cluster

	/*
	* Load the FAT at ES:DI in order to find the required clusters
	*/
	call 	load_fat

	/*
	* Read file clusters
	*/
	mov 	%es, %dx		// segment of FAT
	mov 	%di, %si		// offset of FAT
	xor 	%ax, %ax
	mov 	%ax, %es		// destination segment
	mov 	$LOAD_ADDR, %di		// destination offset
	movw 	disk_cluster, %ax	// first cluster
	call	load_file		// read
	jc 	err_disk

	/*
	* Execute the loader
	*/
	ljmp	$(LOAD_ADDR >> 4), $0	// jump and update segment

/*
* Halt execution
*/
_end:
	cli
1:	hlt
	jmp 1b

/*
* Loader filename
* 11 chars with no null termination
*/
filename:		.ascii  "LOADER  BIN"

/*
* Log messages
*/

	.macro err str
	leaw	\str, %si
	call	puts
	jmp	_end
	.endm

err_disk:		err msg_err_disk
err_no_file:		err msg_err_no_file
msg_err_disk:		.asciz "Read error\n\r"
msg_err_no_file:	.asciz "Loader not found\n\r"

/*
* Includes
*/
	.include "vga.S"
	.include "disk.S"

/*
* End of sector
*/
signature:
	. = _start + 0x1FE	// 512 bytes - signature length
	.word 0xAA55		// boot signature
