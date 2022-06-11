#include "load_kernel.h"
#include "loaddefs.h"
#include <stdint.h>

int __NOINLINE __REGPARM load_kernel(   uint16_t *buffer,
                                        uint16_t *fat,
                                        uint16_t first_cluster)
{
	/* TODO: Find multiboot header, read and relocate ELF binary */

    

    return ERRNO_KERNEL;
}
