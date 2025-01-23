;******************************************************************************
; Spectravideo SVI-328 MegaROM
; (c) 2025 Markus Rautopuro
; 
; Use z88dk to compile, type 'make', see 'makefile' for details.
;
; NOTE: You need to use m4 to preprocess this file!
;

PUBLIC _main                    ; Required by z88dk
_main:

    org 0x0000
    binary "loader.bin"
LOADER_SIZE             equ $

#IF ROM_ID==0
    include "decompressor.asm"
LAUNCHER_ROM_START:
    binary "launcher.bin.zx0"
LAUNCHER_SIZE           equ $ - LAUNCHER_ROM_START 
MAGIC_NUMBER            equ $
; Pad to a hard-coded boundary (LOADER_SIZE + decompressor size + compressed launcher size)
    defs SECTOR0_START-$, 0xff ; If this fails, increase SECTOR0_START in makefile
#ENDIF

dnl This requires m4 preprocessor
define(DATAFILE, `"data_sector'ROM_ID`.bin"')
    binary DATAFILE

    defs 16384-1-$, 0xff	    ; Pad to 16 kB, but leave one byte to ROM_ID
    db ROM_ID                   ; Define via -DROM_ID=x