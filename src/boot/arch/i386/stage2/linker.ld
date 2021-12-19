ENTRY(_start)
SECTIONS
{
	. = 0xBF00;
	.text : { *(.text) }
}