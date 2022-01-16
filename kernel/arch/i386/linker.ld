/* symbol for bootloader to start execution */
ENTRY(_start)
SECTIONS
{
	/* start at 1MiB */
	. = 1M;
	/* multiboot header, code start */
	.text BLOCK(4K) : ALIGN(4K)
	{
		*(.multiboot)
		*(.text)
	}
	/* read-only */
	.rodata BLOCK(4K) : ALIGN(4K)
	{
		*(.rodata)
	}
	/* read-write (initialized) */
	.data BLOCK(4K) : ALIGN(4K)
	{
		*(.data)
	}
	/* read-write (uninitialized), stack */
	.bss BLOCK(4K) : ALIGN(4K)
	{
		*(COMMON)
		*(.bss)
	}
}