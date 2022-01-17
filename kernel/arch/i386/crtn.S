/* C runtime end stub */
	.section .init
    	/* crtend.o .init added by gcc */
	popl	%ebp # pushed in crti.S
	ret

	.section .fini
	/* crtend.o .fini added by gcc */
	popl	%ebp
	ret
