;******************************************************************************
; Spectravideo SVI-328 MegaROM
; (c) 2025 Markus Rautopuro
; 
; Use z88dk to compile, type 'make', see 'makefile' for details.
;

ShowSplash:
    ld a, 1                     ; Screen 1 / Black color
    ld (SVI_RAM_SCREEN), a
    ld (SVI_RAM_BORCLR), a
    ld (SVI_RAM_BACK_COLOR), a
    ld a, 8                     ; Red
    ld (SVI_RAM_FRONT_COLOR), a
    ld (SVI_RAM_ATRBYT), a      ; ATRBYT (for drawing the logo later in red)

    call SVI_ROM_INIGRP
    call SVI_ROM_INIGRP         ; FIXME: INIGRP has to be called twice for it to work

    ld bc, 40                    
    ld de, 82 - 42              ; Move a little bit up (42) from original location
    call SVI_ROM_PRLOGO_SVI     ; Print Spectravideo in red

    ld bc, 56
    ld de, 100 - 42
    ld h, 72
    call SVI_ROM_PRLOGO_LINE    ; First logo line (without loading ATRBYT)

    ld bc, 58
    ld de, 104 - 42
    ld h, 70
    call SVI_ROM_PRLOGO_LINE    ; Second line

    ld bc, 60
    ld de, 108 - 42
    ld h, 68
    call SVI_ROM_PRLOGO_LINE    ; Third line

    ld a, 72
    ld (SVI_RAM_CSRX), a
    ld a, 90
    ld (SVI_RAM_CSRY), a
    PrintBIOS MessageMegaROM

    ld a, 86
    ld (SVI_RAM_CSRX), a
    ld a, 180
    ld (SVI_RAM_CSRY), a
    PrintBIOS MessageCopyright

    call SVI_ROM_PRLOGO_WAIT    ; Execute boot logo waiting procedure
    ret

MessageMegaROM:
    db "SVI-328 MegaROM 1.0", 0

MessageCopyright:
    db "(c) 2025 MAG-4", 0