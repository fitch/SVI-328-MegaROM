;******************************************************************************
; Spectravideo SVI-328 MegaROM
; (c) 2025 Markus Rautopuro
; 
; Use z88dk to compile, type 'make', see 'makefile' for details.
;

    ld hl, DZX0_ROM_START       ; Copy ZX0 decoder to RAM
    ld de, DZX0_ADDRESS
    ld bc, DZX0_SIZE
    ldir

LAUNCHER_RAM_START      equ 0xc000

    ld hl, LAUNCHER_ROM_START
    ld de, LAUNCHER_RAM_START   ; Copy launcher to RAM
    ld bc, LAUNCHER_SIZE
    ldir
    
    ld hl, LAUNCHER_RAM_START   ; Uncompress launcher
    ld de, LAUNCHER_ADDRESS
    push de                     ; This will be the code entrance once decompression is done (ret)
    jp DZX0_ADDRESS             ; Start decompression


DZX0_ROM_START:                 ; ZX0 decoder by Einar Saukas & Urusergi
    phase DZX0_ADDRESS
    include "ZX0/dzx0_standard.asm"
    dephase
DZX0_SIZE               equ $-DZX0_ROM_START
