# Andromeda

The Andromeda Operating System

## Overview

Andromeda is a project to build a Unix-like operating system with the following in mind:

- Monolithic/modular C kernel with multitasking
- POSIX compliance and interoperability with other systems without compromising simplicity

## Hardware support

- i386 or newer IA-32/amd64 CPU
- PC-compatible BIOS firmware

## Build Environment

### Prerequesites

- `sh`
- `make`
- `grub`
    - `grub-file`
    - `grub-mkrescue`
- `libisoburn`
    - `xorriso`
    
- Toolchain (see [Building the Toolchain](###Building-the-Toolchain))
    - `<TARGET>-binutils`
        - `<TARGET>-ar`
        - `<TARGET>-as`
        - `<TARGET>-ld`
    - `<TARGET>-gcc`

Currently supported targets:

- `i386-elf`
- `i486-elf`
- `i586-elf`
- `i686-elf`

### Building the Toolchain

Requires:

- `curl`
- `tar`
- `gcc`

(Optional) Set the installation directory:

`$ ./tools/set_prefix.sh <PREFIX>`

(Optional) Set the target architecture:

`$ ./tools/set_target.sh <TARGET>`

Build the toolchain:

`$ ./tools/build_toolchain.sh`

### Building

`$ make`

`$ make image`

### Testing

*Requires `qemu-system-i386` or `qemu-system-x86_64`*

`$ make qemu`

### Debugging

*Requires QEMU and `gdb`*

`$ make debug`

## License

Released under the GPLv3 license. See `NOTICE` and `COPYING` for details.

## Documentation

Documentation is authored in English and refers to frequently used acronyms in hardware and software architecture and not all acronyms/abbreviations may be cited.

### Index

- [Architecture](doc/architecture.md)
- [Source Code](doc/source.md)
- [External Reference for Development](doc/reference.md)