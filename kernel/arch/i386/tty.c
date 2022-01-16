#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>

#include <kernel/tty.h>

#include "vga.h"

static const size_t VGA_WIDTH = 80;
static const size_t VGA_HEIGHT = 25;
static uint16_t* const VGA_BUFFER = (uint16_t*) 0xb8000;

static size_t terminal_row;
static size_t terminal_column;
static uint8_t terminal_color;
static uint16_t *terminal_buffer;
static bool scroll_next;

static inline void terminal_setdata(unsigned char c, uint8_t color, size_t x, size_t y)
{
	terminal_buffer[vga_index(y, VGA_WIDTH, x)] = vga_entry(c, color);
}

void terminal_clear(void) {
	terminal_row = 0;
	terminal_column = 0;
	scroll_next = false;
	for (size_t y = 0; y < VGA_HEIGHT; y++) {
		for (size_t x = 0; x < VGA_WIDTH; x++) {
			const size_t index = vga_index(y, VGA_WIDTH, x);
			terminal_buffer[index] = vga_entry(VGA_NULL, terminal_color);
		}
	}
}

void terminal_init(void)
{
	terminal_color = vga_entry_color(VGA_FG, VGA_BG);
	terminal_buffer = VGA_BUFFER;
	terminal_clear();
}

void terminal_scroll(void)
{
	size_t y;
	size_t x;
	const size_t last_line = VGA_HEIGHT - 1;
	for (y = 0; y < last_line; y++) {
		for (x = 0; x < VGA_WIDTH; x++) {
			terminal_buffer[y * VGA_WIDTH + x] =
				terminal_buffer[(y + 1) * VGA_WIDTH + x];
		}
	}

	size_t i;
	const uint16_t null_entry = vga_entry(VGA_NULL, terminal_color);
	for (i = last_line * VGA_WIDTH; i < last_line * VGA_WIDTH + VGA_WIDTH; i++) {
		terminal_buffer[i] = null_entry;
	}
}

void terminal_putc(unsigned char c)
{
	const size_t last_row = VGA_HEIGHT - 1;
	if (c == '\n') {
		terminal_column = 0;
		if (terminal_row == last_row) {
			scroll_next = true;
		} else {
			terminal_row++;
		}
	} else {
		if (scroll_next) {
			terminal_scroll();
			scroll_next = false;
		}

		terminal_setdata(c, terminal_color, terminal_column, terminal_row);
		const size_t last_col = VGA_WIDTH - 1;
		if (terminal_column == last_col) {
			terminal_column++;
			if (terminal_row == last_row) {
				scroll_next = true;
			} else {
				terminal_row++;
			}
		} else {
			terminal_column++;
		}
	}
}

void terminal_write(const char *data, size_t size)
{
	for (size_t i = 0; i < size; i++) {
		terminal_putc((unsigned char) data[i]);
	}
}

void terminal_puts(const char *str)
{
	terminal_write(str, strlen(str));
}