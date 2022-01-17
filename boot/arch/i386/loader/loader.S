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

_start:
	lea	msg_load, %si	// loader message
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
	.include "vga.S"

/*
* Messages
*/
msg_load:		.asciz "Loading...\n\r"

/*
* Kernel filename
* 11 chars with no null termination
*/
filename:		.ascii  "KERNEL  ELF"
