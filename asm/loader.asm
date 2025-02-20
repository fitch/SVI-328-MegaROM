;******************************************************************************
; Spectravideo SVI-328 MegaROM
; (c) 2025 Markus Rautopuro
; 
; Use z88dk to compile, type 'make', see 'makefile' for details.
;
; This is the binary code in start of each sector, that ensures that the ROM
; has just switched to show sector 0 and then let's the execution flow to
; the launcher stored in sector 0 of the RAM.
;

PUBLIC _main                    ; Required by z88dk
_main:

ROM_STACK               equ 0xf21c

#ifdef EMULATOR                ; Define ROM_ID address to 0x8000 in emulator so you can change it manually in the RAM debugger
ROM_ID_ADDRESS          equ 0x8000
#else                           ; Otherwise it's the last byte of the 16 kB ROM sector
ROM_ID_ADDRESS          equ 16384-1
#endif

    org 0x0000
    di                          ; di and ld sp, xxxx are required to boot from a ROM
    ld sp, ROM_STACK            ; Place stack for BASIC BIOS compatible location

#ifndef EMULATOR
.wait_for_sector_x:             ; Wait that we'll bypass ROM 0 (that we have time to copy it next time)
    ld a, (ROM_ID_ADDRESS)      ; Check which ROM ID is visible
    or a
    jr z, wait_for_sector_x

.wait_for_sector_0:             ; Wait until CD4060 changes the visible sector back to 0
    ld a, (ROM_ID_ADDRESS)      ; Check which ROM ID is visible
    or a
    jr nz, wait_for_sector_0
#else                           ; In emulator, don't wait for ROM change
    REPT 12
    nop
    ENDR
#endif

; Now we're at sector 0, let execution flow to rom_production.asm / rom_emulator.asm