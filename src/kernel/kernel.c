#include <kernel/tty.h>
#include <kernel/config.h>

void kernel_main(void)
{
	terminal_init();
	terminal_puts(KERNEL_MSG_START);
	return;
}