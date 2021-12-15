# Source Structure

## Languages

- C99 *(ISO/IEC 9899:1999)*
- GNU x86 Assembly *(GNU AS, AT&T Syntax)*

## System Source Structure

- `src/`
    - `boot/`
        - `arch/`
            - `<architecture>/`
                - `*.s`
                - `linker.ld`
                - `make.config`
        - `Makefile`
    - `kernel/`
        - `arch/`
            - `<architecture>/`
                - `*.s`
                - `*.c`
                - `linker.ld`
                - `make.config`
        - `include/`
            - `<component>/`
                - `*.h`
        - `*.c`
        - `Makefile`
    - `libc/`
        - `arch/`
            - `<architecture>/`
                - `make.config`
        - `include/`
            - `<component>/`
                - `*.h`
        - `<component>/`
            - `*.c`
        - `Makefile`

## Makefile Notation

- `C-`: Compiler
- `CPP-`: C preprocessor
- `CXX-`: C++ compiler
- `LD-`: Linker