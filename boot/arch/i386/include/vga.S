	.code16

/*
* Output a null-terminated string in text mode
*	in:	SI -> string
*/
puts:
	pusha
1:	lodsb			// load character from SI into AL
	or	%al, %al
	jz	2f		// exit on null byte

	mov	$0x0E, %ah	// teletype output
	xor	%bx, %bx	// BH = 0 (page number), BL = 0 (foreground color)
	int	$0x10
	jmp	1b		// next
2:	popa
	ret
