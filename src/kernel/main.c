#include <kernel/vga.h>

void kernel_main(void)
{
    vga_init();
    vga_puts("Hello, world!\n");
    return;
}