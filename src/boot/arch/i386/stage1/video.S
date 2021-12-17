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

/*	Clear display
*/
vid_clear:
	pusha
	mov	$0x0500, %ax	# ah = 0x05 (set active page), al = 0 (page number)
	int	$0x10

	mov	$0x0700, %ax	# ah = 0x07 (scroll), al = 0 (scroll all lines)
	mov	$0x07, %bh	# character attribute = light grey on black
	xor	%cx, %cx	# first row = 0, first col = 0
	mov	$0x184F, %dx	# last row = 24 (0x18), last col = 79 (0x4f)
	int	$0x10

	movb	$0x02, %ah	# set cursor position
	xorb	%bh, %bh	# page number
	xor	%dx, %dx	# dh = 0 (top), dl = 0 (left)
	int	$0x10
	popa
	ret
