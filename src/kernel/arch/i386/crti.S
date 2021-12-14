/* C runtime start stub */
	.section .init
	.global _init
	.type _init, @function
_init:
	push	%ebp
	movl	%esp, %ebp
	/* crtbegin.o .init appended by gcc */

	.section .fini
	.global _fini
	.type _fini, @function
_fini:
	push	%ebp
	movl	%esp, %ebp
	/* crtbegin.o .fini appended by gcc */