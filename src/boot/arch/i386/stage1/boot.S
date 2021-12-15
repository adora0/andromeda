/* 	C preprocessor directives 	*/
#include <boot/config.h>

/*	assembler directives		*/
	.code16
	.section .text
	.global _start

/* 	start execution (loaded at 0x7c00)
*	FAT12/16 BPB start (BIOS parameter block)
*/
_start:
bpb:
	/*	E9 (..) 90 opcodes required by FAT specification
	*	jmp short, nop; or jmp
	*/
	jmp	boot		# skip disk format information
	

	/* parameters set by format tools */
	. = _start + 0x03
oem_id:			.space	8, 0	# OEM identifier (max. 8 bytes, space-padded)
sector_size:		.word	0	# bytes per sector
cluster_size:		.byte	0	# sectors per cluster
reserved_sectors:	.word	0	# reserved (boot sector only)
fat_count:		.byte	0	# number of file allocation tables (FATs)
root_entries:		.word	0	# number of root directory entries (must span sectors)
sector_count:		.word	0	# number of 16-bit locgical sectors
media_type:		.byte	0	# media descriptor
fat_sectors:		.word	0	# sectors per FAT
track_sectors:		.word	0	# sectors per track
head_count:		.word	0	# number of heads on storage media
hidden_sectors:		.long	0	# number of hidden sectors
large_sectors:		.long	0	# number of 32-bit sectors

/*	FAT12/16 EBPB (Extended Boot Record) */
	. = _start + 0x024
ebpb:
drive_num:		.byte 0		# BIOS drive number (int 0x13)
nt_flags:		.byte 0		# Windows NT flags (reserved)
volume_signature:	.byte 0		# volume signature (0x28 or 0x29)
volume_serial:		.space 4, 0	# serial for volume tracking (32-bit hex)
volume_label:		.space 11, 0	# volume label string (max. 11 bytes, space-padded)
system_id:		.space 8, 0	# file system type representation (not used)

/* 	boot code start		*/

	. = _start + 0x03E

boot:
	call	vid_clear
	leaw	msg_start, %si
	call	vid_puts	# bootloader start message

	call	disk_reset
	jc	disk_reset_err

	jmp	_end

disk_reset_err:
	leaw	msg_disk_reset_err, %si
	call	vid_puts
	jmp	_end

_end:
	cli
_end__hlt:
	hlt
	jmp _end__hlt

/*	preprocessor includes	*/

	.include "video.S"
	.include "disk.S"

/*	symbols			*/

msg_start:		.asciz BOOT_MSG_START
msg_disk_reset_err:	.asciz "Disk system reset failure\n\r"
msg_disk_read_err:	.asciz "Disk read failure\n\r"

	. = _start + 0x1FE	# 512 bytes - signature length
	.word 0xAA55		# boot signature

/*	uninitialized		*/

	.section .bss

	.org 0x7E00
read_buffer:
