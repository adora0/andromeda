	.code16
	.section .text
	.global _start

_start:
_end:
	cli
_end__hlt:
	hlt
	jmp	_end__hlt