ENTRY(_start)
OUTPUT_FORMAT(binary)
SECTIONS
{
	/* Sections must start at address loaded by initial boot stage */
	. = 0x9E00;
	.text :
    {
        *(.text);
    }
}
