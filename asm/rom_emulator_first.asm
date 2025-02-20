;******************************************************************************
; Spectravideo SVI-328 MegaROM
; (c) 2025 Markus Rautopuro
; 
; Use z88dk to compile, type 'make', see 'makefile' for details.
;
; A version of the ROM to test with the emulator (32 kB).
;
; When you start this in the emulator you need to manually change address
; 0x8000 byte in the debugger to first other than 0 and then back to zero in
; order the loader to start copying data.
;

PUBLIC _main                    ; Required by z88dk
_main:

    org 0x0000

;------------------------------------------------------------------------------
; Sector 0

    binary "build/loader.bin"   ; Wait until ROM switches to sector 0
LOADER_SIZE             equ $

    include "asm/decompressor.asm"
LAUNCHER_ROM_START:
    binary "build/launcher.bin.zx0"
LAUNCHER_SIZE           equ $ - LAUNCHER_ROM_START 
MAGIC_NUMBER            equ $
; Pad to a hard-coded boundary (LOADER_SIZE + decompressor size + compressed launcher size)
    defs SECTOR0_START-$, 0xff  ; If this row fails, increase SECTOR0_START_EMULATOR in the makefile

    binary "build/data_sector0.bin" 
    defs 16384-1-$, 0xff        ; Pad to 16 kB, leave 1 byte for ROM_ID
    db 0                        ; First sector is ROM_ID = 0

;------------------------------------------------------------------------------
; Sector 1

    binary "build/loader.bin"
    binary "build/data_sector1.bin"
    defs 32768-1-$, 0xff	    ; Pad to 32 kB, leave 1 byte for ROM_ID
    db 1                        ; Second sector is ROM_ID = 1