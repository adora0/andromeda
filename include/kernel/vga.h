#ifndef __KERNEL_VGA__
#define __KERNEL_VGA__

#include <stdint.h>
#include <stddef.h>

typedef uint8_t vga_color_t;
typedef uint16_t vga_entry_t;
typedef unsigned char vga_char_t;
typedef vga_entry_t* vga_buffer_t;

struct vga_data
{
	size_t width;
	size_t height;
	size_t row;
	size_t column;
    size_t index;
	vga_color_t color;
	vga_buffer_t buffer;
};

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

#define VGA_WIDTH           80
#define VGA_HEIGHT          25
#define VGA_FG		        VGA_COLOR_LIGHT_GREY
#define VGA_BG		        VGA_COLOR_BLACK
#define VGA_BUFFER_START    (vga_buffer_t) 0xb8000

#define VGA_INDEX(y,w,x)    (y * w + x)
#define VGA_CURRENT_INDEX() (display.row * display.width + display.column)

#define VGA_NULL			(vga_char_t) 0

void vga_init(void);
void vga_clear(void);
void vga_putc(char c);
void vga_write(const char *data, size_t size);
void vga_puts(const char *str);

#endif