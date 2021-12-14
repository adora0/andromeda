/* C runtime end stub */
	.section .init
    	/* crtend.o .init appended by gcc */
	popl	%ebp # pushed in crti.S
	ret

	.section .fini
	/* crtend.o .fini appended by gcc */
	popl	%ebp
	ret