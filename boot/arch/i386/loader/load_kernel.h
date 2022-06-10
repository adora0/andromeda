#include <stdint.h>

#define __NOINLINE  __attribute__ ((noinline))
#define __REGPARM   __attribute__ ((regparm(3)))

int32_t __NOINLINE __REGPARM load_kernel(uint16_t first_cluster);
