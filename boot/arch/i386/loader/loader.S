	/*
	* Kernel loader
	* Executed by real mode boot sector stage
	*/	
	
	.code16
	.section .text
	.global _start

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
	* Addresses start at boot sector
	*/
	.set BOOT_OFFSET,			0x7C00
	.set bpb_oem_id,			BOOT_OFFSET + 0x03		// word
	.set bpb_sector_size,		BOOT_OFFSET + 0x0B		// word
	.set bpb_sectors_cluster,	BOOT_OFFSET + 0x0D		// byte
	.set bpb_reserved_sectors,	BOOT_OFFSET + 0x0E		// word
	.set bpb_fat_count,			BOOT_OFFSET + 0x10		// byte
	.set bpb_root_entries,		BOOT_OFFSET + 0x11		// word
	.set bpb_sector_count,		BOOT_OFFSET + 0x13		// word
	.set bpb_media_type,		BOOT_OFFSET + 0x15		// byte
	.set bpb_sectors_fat,		BOOT_OFFSET + 0x16		// word
	.set bpb_sectors_track,		BOOT_OFFSET + 0x18		// word
	.set bpb_head_count,		BOOT_OFFSET + 0x1A		// word
	.set bpb_hidden_sectors,	BOOT_OFFSET + 0x1C		// long
	.set bpb_large_sectors,		BOOT_OFFSET + 0x20		// long

	/*
	* Disk geometry
	* Variable space and parameters set by boot sector stage
	*/
	/* Temporary */
	.set disk_track,			BOOT_OFFSET + 0x03E		// byte
	.set disk_head,				BOOT_OFFSET + 0x03F		// byte
	.set disk_sector,			BOOT_OFFSET + 0x040		// byte
	.set disk_cluster,			BOOT_OFFSET + 0x041		// word
	/* Set */
	.set drive_number,			BOOT_OFFSET + 0x043		// byte
	.set disk_data_sector,		BOOT_OFFSET + 0x044		// word

_start:
	leaw	msg_load, %si		// loader message
	call	puts

/*
* Halt execution
*/
_end:
	cli
1:	hlt
	jmp 1b

/*
* Includes
*/
	.include	"vga.S"

/*
* Messages
*/
msg_load:			.asciz "Loading...\n\r"

/*
* Kernel filename
* 11 chars with no null termination
*/
filename:			.ascii  "KERNEL  ELF"
