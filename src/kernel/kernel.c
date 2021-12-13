#include <kernel/tty.h>

void kernel_main(void)
{
	terminal_init();
	terminal_puts("Hello, world!\n");
	return;
}