#include "cpu.h"
#include "vga.h"
#include "sys.h"
#include "elf.h"

CODE16

void load_elf(void)
{
    // TODO
}

void elf_err(void)
{
    puts("Failed to load kernel ELF\n\r");
    exit();
}