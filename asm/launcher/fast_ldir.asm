;******************************************************************************
; Spectravideo SVI-328 MegaROM
; (c) 2025 Markus Rautopuro
; 
; Use z88dk to compile, type 'make', see 'makefile' for details.
;

; Up to 19% faster alternative for large LDIRs (break-even at 21 loops)
; https://map.grauw.nl/articles/fast_loops.php
;
; hl = source (“home location”)
; de = destination
; bc = byte count

FastLDIR:
    xor a
    sub c
    and 16 - 1
    add a, a
    ld (FASTLDIR_JUMP_OFFSET), a
    jr nz, $                    ; self modifying code
FASTLDIR_JUMP_OFFSET    equ $-1
.loop:
    REPT 16
    ldi                         ; 16x LDI
    ENDR    
    jp pe, loop
    ret
