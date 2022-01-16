#include <kernel/tty.h>
#include <kernel/config.h>

void kmain(void)
{
	terminal_init();
	terminal_puts(KERNEL_MSG_START);
	return;
}