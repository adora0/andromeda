#ifndef _ARCH_I386_VGA_H
#define _ARCH_I386_VGA_H

#include <stdint.h>

enum VGA_COLOR {
	VGA_COLOR_BLACK = 0,
	VGA_COLOR_BLUE = 1,
	VGA_COLOR_GREEN = 2,
	VGA_COLOR_CYAN = 3,
	VGA_COLOR_RED = 4,
	VGA_COLOR_MAGENTA = 5,
	VGA_COLOR_BROWN = 6,
	VGA_COLOR_LIGHT_GREY = 7,
	VGA_COLOR_DARK_GREY = 8,
	VGA_COLOR_LIGHT_BLUE = 9,
	VGA_COLOR_LIGHT_GREEN = 10,
	VGA_COLOR_LIGHT_CYAN = 11,
	VGA_COLOR_LIGHT_RED = 12,
	VGA_COLOR_LIGHT_MAGENTA = 13,
	VGA_COLOR_LIGHT_BROWN = 14,
	VGA_COLOR_WHITE = 15
};

#define VGA_FG VGA_COLOR_LIGHT_GREY
#define VGA_BG VGA_COLOR_BLACK
#define VGA_NULL ((unsigned char) 0)


static inline uint8_t vga_entry_color(enum VGA_COLOR fg, enum VGA_COLOR bg)
{
	return fg | bg << 4;
}


static inline uint16_t vga_entry(unsigned char c, uint8_t color)
{
	return (uint16_t) c | (uint16_t) color << 8;
}


static inline uint16_t vga_index(size_t y, size_t w, size_t x)
{
	return y * w + x;
}


#endif