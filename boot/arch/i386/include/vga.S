    .code16

/*
 * Output a null-terminated string in text mode
 * in:		SI -> string
*/
puts:
	pusha
1:	lodsb				// load character from %si into %al
	or		%al, %al
	jz		2f			// exit on null byte

	mov		$0x0E, %ah	// teletype output
	xor		%bx, %bx	// bh = 0 (page number), bl = 0 (foreground color)
	int		$0x10
	jmp		1b			// next
2:	popa
	ret
