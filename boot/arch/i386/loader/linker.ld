ENTRY(_start)
OUTPUT_FORMAT(binary)
SECTIONS
{
	/* sections must start at address loaded by initial boot stage */
	. = 0x9000;
	.text : { *(.text) }
}