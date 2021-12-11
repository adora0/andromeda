#include <kernel/vga.h>

/* kernel entry point */
void kernel_main(void)
{
    vga_init();
    vga_puts("Hello, world!");
    return;
}