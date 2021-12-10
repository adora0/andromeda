#ifndef __KERNEL_VGA__
#define __KERNEL_VGA__

#include <stdint.h>

enum VGA_COLOR;

typedef uint8_t vga_color_t;
typedef uint16_t vga_entry_t;
typedef unsigned char vga_char_t;

static inline vga_color_t vga_entry_color(enum VGA_COLOR fg, enum VGA_COLOR bg);
static inline vga_entry_t vga_entry(vga_char_t c, vga_color_t color);

#endif