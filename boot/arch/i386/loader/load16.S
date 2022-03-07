	/*
	* Kernel loader
	* Switch to protected mode to load kernel
	*/	
	
	.code16

	.section .text
	.global _start

	.extern load32

_start:
	ljmp	$0, $1f			// reset code segment

1:	/* Print loader message */
	lea	msg_load, %si
	call	puts

enable_a20:
	/* Enable the A20 line to address memory above 1MiB +64KiB */
	call	3f
	
	call	enable_a20_bios
	jc	1f			// next method
	call	3f

1:	call	enable_a20_8042
	call	3f

2:	call	enable_a20_fast
	jc	err_a20			// all methods failed
	call	3f	

3:	/* Check */
	call	check_a20
	jnc	a20_enabled		// continue if enabled
	ret

a20_enabled:
	/* Switch to protected mode */
	lgdt	gdt_info		// load GDT
	cli
	mov     %cr0, %eax
        or      $1, %al
        mov     %eax, %cr0		// set first bit in control register 0

        jmp     . + 2			// prevent crash on 386/486


	.code32


	/* Load segment registers */
	mov     $0x08, %ax		// select descriptor 1 (0b1000)
        mov     %ax, %ds
        mov     %ax, %es
        mov     %ax, %fs
        mov     %ax, %gs
        mov     %ax, %ss

	/* Call C loader */
	call	load32

/*
* Halt execution
*/
_end:
	cli
1:	hlt
	jmp 1b
	

	.code16


/////////////
// Functions
/////////////


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


/*
* Check status of the A20 address line
*	out:	CF = 0 if enabled
*		CF = 1 if disabled
*/
check_a20:
	push	%ds
	pushf			// save flags to restore interrupts
	cli			// clear interrupts

	xor	%ax, %ax
	mov	%ax, %es	// ES = 0

	not	%ax
	mov	%ax, %ds	// DS = 0xFFFF

	mov	$0x0500, %di
	mov	$0x0510, %si

	mov	%es:(%di), %al	// read 0x0000:0x0500
	push	%ax
	
	mov	%ds:(%si), %al	// read 0xFFFF:0x0510
	push	%ax

	movb	$0x00, %es:(%di)	// clear 0x0000:0x0500
	movb	$0xFF, %ds:(%si)	// set 0xFFFF:0x0500 to 0xFF

	cmpb	$0xFF, %es:(%di)	// check 0x0000:0x0500
	
	pop	%ax
	mov	%al, %ds:(%si)	// restore byte

	pop	%ax
	mov	%al, %es:(%di)	// restore byte

	jne	1f		// 0x0000:0x0500 was not set: memory does not wrap around

	/* A20 disabled if memory wraps around */
	popf			// restore flags
	stc			// set CF if memory does wrap around
	jmp	2f

1:	/* A20 enabled if memory does not wrap around */
	popf			// restore flags
	clc			// clear CF if memory does not wrap around

2:	pop	%ds
	ret


/*
* Enable the A20 line via the BIOS (PS/2 and later specific models)
*	out:	CF = 0 on success
*		CF = 1 on failure
*/
enable_a20_bios:
	/*
	* Int 0x15/AH=0x2403: SYSTEM - later PS/2s - QUERY A20 GATE SUPPORT
	*/
	mov	$0x2403, %ax
	int	$0x15
	jc	2f		// not supported
	cmp	$0, %ah
	jnz	1f
	
	/*
	* Int 0x15/AH=0x2402: SYSTEM - later PS/2s - GET A20 GATE STATUS
	*/
	mov	$0x2402, %ax
	int	$0x15
	jc	2f		// unable to get status
	cmp	$0, %ah
	jnz	1f
	
	cmp	$1, %al
	jz	2f		// already activated
	
	/*
	* Int 0x15/AH=0x2401: SYSTEM - later PS/2s - ENABLE A20 GATE
	*/
	mov	$0x2401, %ax
	int	$0x15
	jc	2f		// failed to enable
	cmp	$0, %ah
	jnz	1f
	
	jmp	2f		// success

1:	stc			// set CF on failure
2:	ret


/*
* Enable the A20 line via the 8042 keyboard controller
*/
enable_a20_8042:
	pushf
	cli

	call	1f		// wait for input buffer
	mov	$0xAD, %al	// disable keyboard
	out	%al, $0x64	// send command

	call	1f		// wait for input buffer
	mov	$0xD0, %al	// read input
	out	%al, $0x64	// send command
	
	call	2f		// wait for output buffer
	in	$0x60, %al	// read input buffer from output port
	push	%ax

	call	1f		// wait for input buffer
	mov	$0xD1, %al	// write to output
	out	%al, $0x64	// send command

	call	1f		// wait for input buffer
	pop	%ax
	
	or	$2, %al		// enable bit 1 (A20)
	out	%al, $0x60	// write to output port

	call	1f		// wait for input buffer
	mov	$0xAE, %al	// enable keyboard
	out	%al, $0x64	// send command

	call	1f
	jmp	3f

1:	/* Wait for input buffer */
	in	$0x64, %al
	test	$2, %al		// bit 1 (input buffer status)
	jnz	1b		// zero when ready
	ret

2:	/* Wait for output buffer */
	in	$0x64, %al
	test	$1, %al		// bit 0 (output buffer status)
	jz	2b		// non-zero when ready
	ret

3:	popf
	ret


/*
* Enable the A20 line via the Fast A20 port (PS/2 and later)
*	out:	CF = 0 if supported
*		CF = 1 on failure
*/
enable_a20_fast:
	pushf
	cli			// disable interrupts

	in	$0x92, %al
	test	$2, %al
	jnz	1f		// unsupported
	or	$2, %al		// set bit 1 for Fast A20
	and	$0xFE, %al	// do not write to bit 0
	out	%al, $0x92	// write

	clc
	jmp	2f

1:	popf
	stc
2:	ret


/*
* Global Descriptor Table
* Flat 4GiB with no address translation
*/
gdt_info:
        .word   gdt_end - gdt_start - 1	// last byte in table
	.long	gdt_start		// start of table

gdt_start:
	/* Null descriptor */
	.long	0
	.long	0
	/* Code descriptor */
	.word	0xFFFF		// segment limit (bits 0-16)
	.word	0		// base address (bits 0-16)
	.byte	0		// base address (bits 16-23)
	.byte	0b10010010	// type, privilege level, present flag
	.byte	0b11001111	// segment limit (bits 16-19), attributes, granularity
	.byte	0		// base address (bits 24-31)
gdt_end:


/*
* Messages
*/

	.macro err str
	leaw	\str, %si
	call	puts
	jmp	_end
	.endm

msg_load:		.asciz "Loading...\n\r"
msg_err_a20:		.asciz "Failed to enable A20 line\n\r"
err_a20:		err msg_err_a20
