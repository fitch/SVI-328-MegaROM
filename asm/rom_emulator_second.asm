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
; Sector 2

    binary "build/loader.bin"   ; Wait until ROM switches to sector 0
    binary "build/data_sector2.bin" 

    defs 16384-1-$, 0xff
    db 2

;------------------------------------------------------------------------------
; Sector 3

    binary "build/loader.bin"
    binary "build/data_sector3.bin"
    defs 32768-1-$, 0xff
    db 3