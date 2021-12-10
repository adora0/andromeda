# Source Code

## Languages

- C99 *(ISO/IEC 9899:1999)*
- NASM x86 Assembly *(Netwide Assembler)*

## System Source Structure

```
├── include/
│   └── COMPONENT/
│       ├── *.h     —— C header
│       │               (definitions)
│       └── *.inc   —— asm include
└── src/
    └── COMPONENT/
        ├── *.c     —— C source
        │               (declerations)
        └── *.s     —— asm source
```