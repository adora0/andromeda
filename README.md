# Cosmos

*Cosmos*: The Cosmos Operating System

## Overview

Cosmos is structured to be a Unix-like operating system with the following characteristics in mind:

- Free and open-source
- Monolithic, modular, multitasking kernel with runtime flexibility and stability
- C kernel codebase (C99)
- POSIX compliance and interoperability with other systems without compromising simplicity

The system is structured to comprise a basic kernel, bootloader and userspace command-line interface at its core, with the goal of writing the basis for a flexible operating system as a personal project in software architecture IA-32 programming.

## Hardware support

- Target
    - x86_64 64-bit CPU *(AMD64/Intel64 compatible, AMD Opteron / Intel Pentium 4 Prescott and newer)*
    - UEFI 2.0 compatible firmware
- Base
    - i586 32-bit CPU *(IA-32 compatible, Intel Pentium and newer)*
    - IBM PC-compatible BIOS firmware 

## Build

### Prerequesites

See `DEPENDENCIES` for a newline-separated list of build dependencies. Package names are taken from the default Arch Linux package repositories and are primarily from the GNU utilities.

### Setup

`$ ./sysbuild.sh configure`

Prepares build environment and builds the toolchain.

### Compilation

`$ make`

### Testing

`$ make run`

## License

Released under the GPLv3 license. See `NOTICE` and `COPYING` for details.

## Documentation

Documentation is currently authored in English (United States) and refers to frequently used acronyms in hardware and software architecture and not all acronyms/abbreviations may be cited.

### Index

1. [Building](doc/build.md)
2. [Architecture](doc/architecture.md)
3. [Source Code](doc/source.md)
4. [External Reference for Development](doc/reference.md)