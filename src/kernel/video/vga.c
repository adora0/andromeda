#include <kernel/video/vga.h>
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

static inline vga_color_t vga_entry_color(enum VGA_COLOR fg, enum VGA_COLOR bg)
{
    return fg | bg << 4;
}

static inline vga_entry_t vga_entry(vga_char_t c, vga_color_t color)
{
    return (vga_entry_t) c | (vga_entry_t) color << 8;
}