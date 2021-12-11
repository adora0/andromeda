#include <stdint.h>
#include <kernel/vga.h>
#include <sys/string.h>

static struct vga_data display;

static inline vga_color_t vga_entry_color(enum VGA_COLOR fg, enum VGA_COLOR bg)
{
    return fg | bg << 4;
}

static inline vga_entry_t vga_entry(vga_char_t c, vga_color_t color)
{
    return (vga_entry_t) c | (vga_entry_t) color << 8;
}

void vga_init(void)
{
	/* initialize display struct */
	display.width = VGA_WIDTH;
	display.height = VGA_HEIGHT;
	display.color = vga_entry_color(VGA_FG, VGA_BG);
	display.buffer = VGA_BUFFER_START;
	/* clear buffer */
	vga_clear();
}

void vga_clear(void)
{
	size_t y,x,index;
	vga_entry_t entry = vga_entry(VGA_NULL, display.color);
	for (y=0; y<display.height; y++) {
		for (x=0; x<display.width; x++) {
			index = VGA_INDEX(y, x, VGA_WIDTH);
			display.buffer[index] = entry;
		}
	}
}

void vga_putc(char c)
{
	display.index = VGA_CURRENT_INDEX();
	display.buffer[display.index] = c;
	if (++display.column == display.width) {
		display.column = 0;
		if (++display.row == display.height) {
			display.row = 0;
		}
	}
}

void vga_write(const char *data, size_t size)
{
	for (size_t i=0; i<size; i++)
		vga_putc(data[i]);
}

void vga_puts(const char *str)
{
	vga_write(str, strlen(str));
}