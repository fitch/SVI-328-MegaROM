MACRO Print address
	ld hl,address
	call PrintString
ENDM

PUBLIC _main                    ; Required by z88dk
_main:

ROM_STACK   			equ 0xf21c

	org 0x0000					
	di                          ; di and ld sp, xxxx are required to boot from a ROM
	ld sp, ROM_STACK

    ld de, RAM_START
    ld hl, ROM_START
    ld bc, RAM_END - RAM_START
    ldir

    jp RAM_START

ROM_START:
    phase 0x8000
RAM_START:

    call PSG_show_BIOS_ROM

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
    Print MessageMegaROM

    ld a, 86
    ld (SVI_RAM_CSRX), a
    ld a, 180
    ld (SVI_RAM_CSRY), a

    Print MessageCopyright

    call SVI_ROM_PRLOGO_WAIT

    call SVI_ROM_ERAFNK
    call SVI_ROM_INITXT

    di
    halt


MessageMegaROM:
    db "SVI-328 MegaROM 1.0", 0

MessageCopyright:
    db "(c) 2025 MAG-4", 0


SVI_ROM_CHGET			equ 0x003e
SVI_ROM_CHPUT			equ 0x394d
SVI_ROM_INITXT			equ 0x3541
SVI_ROM_INIGRP			equ 0x3610
SVI_ROM_ERAFNK			equ 0x3b86
SVI_ROM_PRLOGO_SVI      equ 0x47e5
SVI_ROM_PRLOGO_LINE     equ 0x4835
SVI_ROM_PRLOGO_WAIT     equ 0x47ce

SVI_RAM_CURSOR_STATUS	equ 0xfa05
SVI_RAM_CSRX            equ 0xfa04
SVI_RAM_CSRY            equ 0xfa03
SVI_RAM_SCREEN          equ 0xfe3a
SVI_RAM_FRONT_COLOR     equ 0xfa0a
SVI_RAM_BACK_COLOR      equ 0xfa0b
SVI_RAM_BORCLR          equ 0xfa0c
SVI_RAM_ATRBYT          equ 0xfa13

PSG_ADDRESS_LATCH		equ 0x88
PSG_DATA_WRITE			equ 0x8c
PSG_DATA_READ			equ 0x90
PSG_REGISTER_R7			equ 0x7
PSG_REGISTER_R15		equ 0xf

VDP_DATA_WRITE			equ 0x80
VDP_ADDRESS_REGISTER 	equ 0x81
VDP_DATA_READ			equ 0x84
VDP_RESET_STATUS		equ 0x85

; Function to switch BASIC BIOS ROM

PSG_show_BIOS_ROM:
    di
	ld a, PSG_REGISTER_R15		; Port B is controlled via register 15
	out	(PSG_ADDRESS_LATCH), a
	in a, (PSG_DATA_READ)
    or %00000011				; Disable CART, low = active (the lower bank cartridge ROM), also disable BK21 if enabled
	out (PSG_DATA_WRITE), a		; Execute switching the RAM to higher bank
	ret

; Function to switch BASIC BIOS ROM

PSG_show_cartridge_ROM:
    di
	ld a, PSG_REGISTER_R15		; Port B is controlled via register 15
	out	(PSG_ADDRESS_LATCH), a
	in a, (PSG_DATA_READ)
    or %00000010                ; Disable BK21 if enabled
	and %11111110				; Enable CART, low = active (the lower bank cartridge ROM)
	out (PSG_DATA_WRITE), a		; Execute switching the RAM to higher bank
	ret

; Function to disable lower bank cartridge ROM and use lower bank RAM instead

PSG_disable_CART_enable_BK21:
    di
	ld a, PSG_REGISTER_R15		; Port B is controlled via register 15
	out	(PSG_ADDRESS_LATCH), a
	in a, (PSG_DATA_READ)
    or %00000001				; Disable CART, low = active
	and %11111101				; Enable BK21 (the lower bank RAM)
	out (PSG_DATA_WRITE), a		; Execute switching the RAM to higher bank
	ret

; Function to set background color

VDP_set_background_color:
    di
	push af
	in a, (VDP_RESET_STATUS)
	pop af
    out (VDP_ADDRESS_REGISTER), a
	ld a, 7 | 0x80				; Write to register 7
    out (VDP_ADDRESS_REGISTER), a
	ret

; Function to print a 255 terminated string

PrintString:
	ld a, (hl)			
	cp 0
	ret z
	inc hl
	call SVI_ROM_CHPUT
	jr PrintString

RAM_END:
    dephase

    defs 32768-$, 0xff	        ; Pad to 32 kB