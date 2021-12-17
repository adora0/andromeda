	.code16
	.global vid_puts
	.global vid_clear

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
