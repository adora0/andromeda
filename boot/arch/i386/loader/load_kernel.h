#ifndef _ARCH_I386_BOOT_LOAD_KERNEL
#define _ARCH_I386_BOOT_LOAD_KERNEL


#include <stdint.h>

#define __NOINLINE  __attribute__ ((noinline))
#define __REGPARM   __attribute__ ((regparm(3)))


int __NOINLINE __REGPARM load_kernel(   uint16_t *buffer,
                                        uint16_t *fat,
                                        uint16_t first_cluster);

extern int __REGPARM read_sectors_32(   uint16_t lba,
                                        uint16_t n_sectors, uint32_t buffer);


#endif
