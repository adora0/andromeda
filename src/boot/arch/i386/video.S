	.code16

/*	Function:	output a null-terminated string from %si
*/
puts:
	pusha
puts__next:
	lodsb			# load character from %si into %al
	or	%al, %al
	jz	puts__exit	# exit on null byte

	movb	$0x0E, %ah	# teletype output
	xor	%bx, %bx	# bh = 0 (page number), bl = 0 (foreground color)
	int	$0x10

	jmp	puts__next	# next
puts__exit:
	popa
	ret

/*	Function:	clear display
*/
clear:
	pusha

	mov	$0x0500, %ax	# ah = 05h (set active page), al = 0 (page number)
	int	$0x10

	mov	$0x0700, %ax	# ah = 07h (scroll), al = 0 (scroll all lines)
	mov	$0x07, %bh	# character attribute = light grey on black
	xor	%cx, %cx	# first row = 0, first col = 0
	mov	$0x184F, %dx	# last row = 24 (18h), last col = 79 (4fh)
	int	$0x10

	movb	$0x02, %ah	# set cursor position
	xorb	%bh, %bh	# page number
	xor	%dx, %dx	# dh = 0 (top), dl = 0 (left)
	int	$0x10

	popa
	ret
