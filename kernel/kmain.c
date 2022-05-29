#include <kernel/config.h>
#include <kernel/tty.h>

void kmain(void)
{
	terminal_init();
	terminal_puts(KERNEL_MSG_START);
	return;
}