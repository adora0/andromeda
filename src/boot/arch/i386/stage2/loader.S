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


/*	Output a null-terminated string in text mode
*	Parameters:	SI -> string
*/
vid_puts:
	pusha
vid_puts__next:
	lodsb			# load character from %si into %al
	or	%al, %al
	jz	vid_puts__exit	# exit on null byte

	movb	$0x0E, %ah	# teletype output
	xor	%bx, %bx	# bh = 0 (page number), bl = 0 (foreground color)
	int	$0x10

	jmp	vid_puts__next	# next
vid_puts__exit:
	popa
	ret


/*	Symbols			*/
msg_stage2_start:	.asciz "Loaded bootloader stage 2"
