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

static inline void vga_set(size_t index, vga_char_t c, vga_color_t color)
{
	display.buffer[index] = vga_entry(c, color);
	return;
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
	return;
}

void vga_clear(void)
{
	size_t index;
	for (size_t y=0; y<display.height; y++) {
		for (size_t x=0; x<display.width; x++) {
			index = VGA_INDEX(y, VGA_WIDTH, x);
			vga_set(index, VGA_NULL, display.color);
		}
	}
	return;
}

void vga_putc(char c)
{
	if (c == ENDL) {
		if (++display.row == display.height)
			display.row = 0;
		display.column = 0;
	} else {
		vga_set(display.index, c, display.color);
		if (++display.column == display.width) {
			display.column = 0;
			if (++display.row == display.height)
				display.row = 0;
		}
	}
	display.index = VGA_CURRENT_INDEX();
	return;
}

void vga_write(const char *data, size_t size)
{
	for (size_t i=0; i<size; i++)
		vga_putc(data[i]);
	return;
}

void vga_puts(const char *str)
{
	vga_write(str, strlen(str));
	return;
}