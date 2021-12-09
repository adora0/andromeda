# Source Code

## Languages

- C99 *(ISO/IEC 9899:1999)*
- GNU x86 Assembly *(GNU Assembler)*

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