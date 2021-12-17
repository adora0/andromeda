	.code16
	.section .text
	.global _start

/*	Start execution (loaded by stage 1)	*/
_start:
	leaw	msg_stage2_start, %si
	call	vid_puts
	jmp	_end

_end:
	cli
_end__hlt:
	hlt
	jmp	_end__hlt


/*	Includes		*/
	.include "video.S"

/*	Symbols			*/
msg_stage2_start:	.asciz "Loaded bootloader stage 2"
