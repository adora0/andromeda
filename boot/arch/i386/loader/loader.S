	.code16
	.section .text
	.global _start

_start:
	/* print start message */
	leaw	msg_start, %si
	call	puts

/*
 * Halt execution
*/
_end:
	cli
1:	hlt
	jmp 1b


/*
 * Output a null-terminated string in text mode
 * in:		SI -> string
*/
puts:
	pusha
1:	lodsb				// load character from %si into %al
	or		%al, %al
	jz		2f			// exit on null byte

	movb	$0x0E, %ah	// teletype output
	xor		%bx, %bx	// bh = 0 (page number), bl = 0 (foreground color)
	int		$0x10
	jmp		1b			// next
2:	popa
	ret

msg_start:		.asciz "Started kernel loader"
