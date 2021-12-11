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
	/* fill each column in each row with null characters */
	for (size_t index,y=0; y<display.height; y++) {
		for (size_t x=0; x<display.width; x++) {
			index = VGA_INDEX(y, VGA_WIDTH, x);
			vga_set(index, VGA_NULL, display.color);
		}
	}
	return;
}

void vga_scroll(size_t rows)
{
	/* limit adjustment range */
	size_t offset;
	if (rows < display.height)
		offset = rows;
	else
		offset = display.height;
	
	/* clear lines from top to line with index of offset */
	for (size_t index, y=0; y<offset; y++) {
		for (size_t x=0; x<display.width; x++) {
			index = VGA_INDEX(y, VGA_WIDTH, x);
			vga_set(index, VGA_NULL, display.color);
		}
	}
	/* copy data from offset to current index for each line */
	for (size_t y_scroll, index_current, index_scroll, y=0; y<display.height-offset; y++) {
		y_scroll = y+offset;
		for (size_t x=0; x<display.width; x++) {
			index_current = VGA_INDEX(y, VGA_WIDTH, x);
			index_scroll = VGA_INDEX(y_scroll, VGA_WIDTH, x);
			display.buffer[index_current] = display.buffer[index_scroll];
		}
	}
	/* clear lines from bottom minus offset */
	for (size_t index, y=display.height-offset; y<display.height; y++) {
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
		/* increment row if newline, scroll if past height */
		display.column = 0;
		size_t next_row = display.row + 1;
		if (next_row == display.height) {
			vga_scroll(1);
		} else {
			display.row = next_row;
		}
	} else {
		/* set data, increment column, increment row if past width, scroll if past height */
		if (++display.column == display.width) {
			display.column = 0;
			size_t next_row = display.row + 1;
			if (next_row == display.height) {
				vga_scroll(1);
			} else {
				display.row = next_row;
			}
		}
		vga_set(display.index, c, display.color);
	}
	/* update buffer index */
	display.index = VGA_INDEX(display.row, display.width, display.column);
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