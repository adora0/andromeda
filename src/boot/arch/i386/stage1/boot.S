#include <boot/config.h>

	.code16
	.section .text
	.global _start

/* 	Start execution (loaded at 0x7c00)	*/
_start:
	/*	E9 (..) 90 opcodes required by FAT specification
	*	jmp short, nop; or jmp
	*/
	jmp	boot
	

/*	FAT12/16 BPB start (BIOS parameter block)
*	parameters set in format 		*/
	. = _start + 0x03
bpb_oem_id:		.space	8, 0	# OEM identifier (max. 8 bytes, space-padded)
bpb_sector_size:	.word	0	# bytes per sector
bpb_sectors_cluster:	.byte	0	# sectors per cluster
bpb_reserved_sectors:	.word	0	# reserved (boot sector only)
bpb_fat_count:		.byte	0	# number of file allocation tables (FATs)
bpb_root_entries:	.word	0	# number of root directory entries (must span sectors)
bpb_sector_count:	.word	0	# number of 16-bit locgical sectors
bpb_media_type:		.byte	0	# media descriptor
bpb_sectors_fat:	.word	0	# sectors per FAT
bpb_sectors_track:	.word	0	# sectors per track
bpb_head_count:		.word	0	# number of heads on storage media
bpb_hidden_sectors:	.long	0	# number of hidden sectors
bpb_large_sectors:	.long	0	# number of 32-bit sectors

/*	FAT12/16 EBPB (Extended Boot Record) */
	. = _start + 0x024
ebpb:
ebpb_drive_num:		.byte 0		# BIOS drive number (int 0x13)
ebpb_nt_flags:		.byte 0		# Windows NT flags (reserved)
ebpb_volume_signature:	.byte 0		# volume signature (0x28 or 0x29)
ebpb_volume_serial:	.space 4, 0	# serial for volume tracking (32-bit hex)
ebpb_volume_label:	.space 11, 0	# volume label string (max. 11 bytes, space-padded)
ebpb_system_id:		.space 8, 0	# file system type representation (not used)


	. = _start + 0x03E

boot:
	call	vid_clear
	leaw	msg_start, %si
	call	vid_puts		# bootloader start message

	xor	%dl, %dl		# dl = drive number
	call	disk_reset
	jc	disk_reset_err

	mov	$2, %ax			# ax = LBA 2
	mov	$1, %cx			# cx = single sector
	xor	%bx, %bx
	movw	%bx, %es		# es: = buffer segment
	leaw	read_buffer, %bx	# bx = buffer offset	
	call	disk_read		# read
	jc	disk_read_err

	jmp	read_buffer		# execute instruction read into buffer

	jmp	_end

disk_reset_err:
	leaw	msg_disk_reset_err, %si
	call	vid_puts
	jmp	_end

disk_read_err:
	leaw	msg_disk_read_err, %si
	call	vid_puts
	jmp	_end

_end:
	cli
_end__hlt:
	hlt
	jmp _end__hlt


/*	Includes		*/

	.include "video.S"
	.include "disk.S"


/*	Symbols			*/

msg_start:		.asciz BOOT_MSG_START
msg_disk_reset_err:	.asciz "Disk system reset failure\n\r"
msg_disk_read_err:	.asciz "Disk read failure\n\r"

	. = _start + 0x1FE	# 512 bytes - signature length

	.word 0xAA55		# boot signature

/*	Uninitialized		*/

	.section .bss

	.org 0x7E00
read_buffer:
