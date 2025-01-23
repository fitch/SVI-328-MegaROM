;******************************************************************************
; Spectravideo SVI-328 MegaROM
; (c) 2025 Markus Rautopuro
; 
; Use z88dk to compile, type 'make', see 'makefile' for details.
;

#ifndef _main                   ; When this is compiled on its own, we'll need to define _main for z88dk
PUBLIC _main
_main:
#endif

#ifdef SIMULATOR                ; Define ROM_ID address to 0x8000 in simulator so you can change it manually in the RAM debugger
ROM_ID_ADDRESS          equ 0x8000
#else                           ; Otherwise it's the last byte of the 16 kB ROM sector
ROM_ID_ADDRESS          equ 16384-1
#endif

MACRO PrintBIOS address
    ld hl, address
    call PrintString
ENDM

MACRO PrintVRAM address
    ld hl, address
    call PrintStringVRAM
ENDM

    org LAUNCHER_ADDRESS        ; This is a hard-coded entry address of the simulator
LAUNCHER_START:
    call PSG_show_BIOS_ROM

    call ShowSplash
    call ShowGameSelector       ; Leaves selected game in a

    ld hl, GameDataTable        ; Warning: this code will start overwriting code from LAUNCHER_ADDRESS
    ld d, 0
    ld e, a
    add hl, de                  ; Move pointer to select the address of correct game data
    add hl, de
    ld a, (hl)
    inc hl
    ld h, (hl)
    ld l, a
    ld de, SelectedGameData     ; Copy two consecutive game datas
    ld bc, SelectedGameDataLength * 2

#if CHECK_CRC=1                 ; Since we're overwriting code from LAUNCHER_ADDRESS, we need to make some space for SelectedGameData
    REPT 18*2-($-LAUNCHER_START)
    nop
    ENDR
#else
    REPT 16*2-($-LAUNCHER_START)
    nop
    ENDR
#endif
    ldir

    ld a, (GameType)
    cp a, 0x04                  ; msx.32.pletter.1 (part 1)
    jr z, load_exerom
    cp a, 0x06                  ; msx.32.zx0.1 (part 1)
    jr z, load_exerom
    cp a, 0x08                  ; msx.16.zx0
    jr z, load_exerom

    jr load_another_part
.load_exerom                    ; For MSX games, load EXEROM from 
#if EXEROM_DISABLE=0
    ld de, EXEROM_TARGET_ADDRESS; Initialize MSX loader by copying it to high RAM and executing the initializer
    ld hl, EXEROM_SOURCE_ADDRESS
    ld bc, EXEROM_COPY_LENGTH
    call FastLDIR

    call PSG_show_BIOS_ROM
    call EXEROM_INITIALIZE      
    call PSG_show_cartridge_ROM
#endif
#if EXEROM_DISABLE=1            ; If EXEROM is disabled, can't run type 0x4 / 0x6 / 0x8 game
    jp not_supported
#endif

.load_another_part:             ; Load another part of the game in msx.32.pletter
    call PSG_show_cartridge_ROM	; Switch cartridge ROM back to access game data

; Load the game data from cartridge ROM to upper RAM
    ld a, (GameStartSector)		; GameStartSector = first sector of that chunk where the selected game is   
    ld b, a
.wait_for_not_start_sector:     ; Wait until that sector is not visible
    ld a, (ROM_ID_ADDRESS)		; Check which ROM ID is visible
    cp b
    jr z, wait_for_not_start_sector	

.wait_for_start_sector:         ; Then, wait until the start sector is visible (to be able to copy it fully)
    ld a, (ROM_ID_ADDRESS)		; Check which ROM ID is visible
    cp b
    jr nz, wait_for_start_sector

    push bc
    ld hl, (GameIndex)          ; Game location in first sector

#ifdef SIMULATOR                ; If in simulator, we're using a 32 kB ROM so the sector 1 is at 16384
    ld a, (GameStartSector)
    cp a, 1
    jr z, adjust_address        ; If sector 1, it resides in the 2nd block in 32 kB simulator ROM
    cp a, 3
    jr z, adjust_address        ; If sector 3, it resides in the 2nd block in 32 kB simulator ROM

    jr continue
.adjust_address:
    add hl, 0x4000              ; If sector 1, in simulator it's in the upper 16 kB
.continue:
#endif

    ld de, (GameLoadAddress)    ; Copy first part of the game to higher RAM
    ld a, (GameType)
    cp a, 0x02                  ; cas.16
    jr z, load_game_data
    cp a, 0x03                  ; cas.8
    jr z, load_game_data
    cp a, 0x04                  ; msx.32.pletter.1 (part 1)
    jr z, load_game_data
    cp a, 0x05                  ; msx.32.pletter.2 (part 2)
    jr z, load_game_data
    ld de, (GameCompressedAddress); Copy MSX game parts to higher RAM at safe location where uncompression doesn't overwrite it
    cp a, 0x06                  ; msx.32.zx0.1 (part 1)
    jr z, load_game_data
    cp a, 0x07                  ; msx.32.zx0.2 (part 2)
    jr z, load_game_data
    cp a, 0x08                  ; msx.16.zx0
    jr z, load_game_data
    cp a, 0x0a                  ; rom.48.zx0.2 (part 2)
    jr z, game_type_10
    cp a, 0x0c                  ; cas.len.zx0
    jr z, load_game_data

    pop bc                      ; 0x00 cas.16.zx0, 0x01 rom.32.zx0, 0x09 rom.48.zx0.1 (part 1), 0x0a rom.48.zx0.2 (part 2), 0x0b rom.48.zx0
    ld sp, DZX0_ADDRESS         ; Move stack as high as possible to make room for the game data (not BASIC BIOS compatible!)
    push bc
    ld de, GAME_DATA_STORAGE    ; Copy game to a temporary location and then uncompress it
    jr load_game_data
.game_type_10:                  ; For rom.48.zx0.2, move stack as high as possible and use GameCompressedAddress
    pop bc
    ld sp, DZX0_ADDRESS
    push bc
    jr load_game_data
.load_game_data:
    ld bc, (GameSizeFirstSector)
    call FastLDIR               ; Copy from ROM cartridge as fast as possible
    pop bc                      ; Pop the game start sector

    ld a, (ROM_ID_ADDRESS)      ; Check that we're still displaying the same sector (error if not)
    cp b
    jp nz, sector_changed_too_early

    ld hl, (GameSizeSecondSector)
    ld a, h                     ; FIXME: Is this the only way to check that hl is zero?
    or a
    jp nz, load_second_sector
    ld a, l
    or a
    jp z, start_uncompression

.load_second_sector:
    inc b                       ; Load the next sector
    push bc
.wait_until_sector_changes:     ; Wait until next sector is visible
    ld a, (ROM_ID_ADDRESS)		; Check which ROM ID is visible
    cp b
    jr nz, wait_until_sector_changes

    ld hl, LOADER_SIZE          ; Any other sector than 0 starts always at LOADER_SIZE
#ifdef SIMULATOR                ; If in simulator, sectors 1 and 3 start at LOADER_SIZE + 16384
    cp a, 1
    jr z, adjust_address2       ; If sector 1, it resides in the 2nd block in 32 kB simulator ROM
    cp a, 3
    jr z, adjust_address2       ; If sector 3, it resides in the 2nd block in 32 kB simulator ROM

    jr continue2
.adjust_address2:
    ld hl, LOADER_SIZE + 16384
.continue2:
#endif

    ld bc, (GameSizeSecondSector)
    call FastLDIR               ; Copy from ROM cartridge as fast as possible
    pop bc                      ; Pop the game start sector

    ld a, (ROM_ID_ADDRESS)      ; Check that we're still displaying the same sector (error if not)
    cp b
    jp nz, sector_changed_too_early

    ld hl, (GameSizeThirdSector); Check if the game occupies a third sector
    ld a, h
    or a
    jp nz, load_third_sector
    ld a, l
    or a
    jp z, start_uncompression

.load_third_sector:
    inc b
    push bc
.wait_until_sector_changes2:    ; Wait until next sector is visible
    ld a, (ROM_ID_ADDRESS)		; Check which ROM ID is visible
    cp b
    jr nz, wait_until_sector_changes2

    ld hl, LOADER_SIZE          ; The third sector always starts after LOADER_SIZE
#ifdef SIMULATOR                ; If in simulator, sectors 1 and 3 start at LOADER_SIZE + 16384
    cp a, 1
    jr z, adjust_address3       ; If sector 1, it resides in the 2nd block in 32 kB simulator ROM
    cp a, 3
    jr z, adjust_address3       ; If sector 3, it resides in the 2nd block in 32 kB simulator ROM

    jr continue3
.adjust_address3:
    ld hl, LOADER_SIZE + 16384
.continue3:
#endif


    ld bc, (GameSizeThirdSector)
    call FastLDIR               ; Copy from ROM cartridge as fast as possible
    pop bc                      ; Pop the game start sector

    ld a, (ROM_ID_ADDRESS)      ; Check that we're still displaying the same sector (error if not)
    cp b
    jp nz, sector_changed_too_early

.start_uncompression            ; Switch cartridge ROM from lower bank to RAM    
    ld a, (GameType)
    or a                        ; FIXME: Verify that this compares to 0
    jr z, loader_cas_16_zx0
    cp 0x0c
    jr z, caslen_zx0_loader
    cp 0x01
    jp z, rom32_zx0_loader
    cp 0x02
    jr z, cas16_loader
    cp 0x03
    jr z, cas8_loader
#if EXEROM_DISABLE=0 
    cp 0x04                     ; msx.32.pletter.1
    jp z, continue_msx32_pletter
    cp 0x05                     ; msx.32.pletter.2
    jp z, EXEROM_32KB_PL_PART2  ; MSX loader: 32 kB ROM-file second part (packed with Pletter)
    cp 0x06                     ; msx.32.zx0.1
    jp z, continue_msx32_zx0
    cp 0x07                     ; msx.32.zx0.2
    jp z, finish_msx32_zx0
    cp 0x08                     ; msx.16.zx0
    jp z, msx16_zx0_loader
#endif
    cp 0x09                     ; rom.48.zx0.1
    jp z, continue_rom48_zx0
    cp 0x0a                     ; rom.48.zx0.2
    jp z, finish_rom48_zx0
    cp 0x0b                     ; rom.48.zx0
    jp z, loader_rom_48_zx0
    jp not_supported            ; Not supported type

.cas16_loader:                  ; Uncompressed 16 kB .CAS game 
    call PSG_show_BIOS_ROM      ; cas.16 games require BASIC BIOS ROM to be visible

#if CHECK_CRC=1
    ld de, (GameLoadAddress)
    ld bc, 16384
    call Verify_Game_CRC16
#endif

    ld hl, (GameJumpAddress)
    jp (hl)

.cas8_loader:                   ; Uncompressed 8 kB .CAS game
    call PSG_show_BIOS_ROM      ; cas.8 games require BASIC BIOS ROM to be visible

#if CHECK_CRC=1
    ld de, (GameLoadAddress)
    ld bc, 8192
    call Verify_Game_CRC16
#endif
    
    ld hl, (GameJumpAddress)
    jp (hl)

.loader_cas_16_zx0:             ; Compressed 16 kB .CAS game
    call PSG_disable_CART_enable_BK21
    ld de, 0x0000
    ld hl, GAME_DATA_STORAGE
    call DZX0_ADDRESS           ; Decompress the ROM data to lower bank

    ld sp, GameLoadAddress      ; Move stack below the game so that it will not be overwritten
    ld de, (GameLoadAddress)    ; Move game to correct address
    ld hl, 0x0000
    ld bc, 16384                ; 16 kB game
    call FastLDIR

#if CHECK_CRC=1
    ld de, (GameLoadAddress)
    ld bc, 16384
    call Verify_Game_CRC16
#endif

    call PSG_show_BIOS_ROM      ; cas.16 games require BASIC BIOS ROM to be visible
    ld hl, (GameJumpAddress)
    jp (hl)

.caslen_zx0_loader:
    call PSG_show_BIOS_ROM      ; cas.len games require BASIC BIOS ROM to be visible
    ld hl, (GameJumpAddress)
    push hl

    ld de, (GameLoadAddress)
    ld hl, (GameCompressedAddress)
    jp DZX0_ADDRESS

.rom32_zx0_loader:
    call PSG_disable_CART_enable_BK21

    ld de, (GameLoadAddress)
    ld hl, GAME_DATA_STORAGE
    call DZX0_ADDRESS           ; Decompress the ROM data to lower bank

#if CHECK_CRC=1
    ld de, (GameLoadAddress)
    ld bc, 32768
    call Verify_Game_CRC16
#endif

    ld hl, (GameJumpAddress)
    jp (hl)

.sector_changed_too_early:
    ld de, 0 + 23 * 40          ; Bottom left corner
    PrintVRAM MessageErrorTooEarly
.halt
    jr halt

.not_supported:
    ld de, 0 + 23 * 40          ; Bottom left corner
    PrintVRAM MessageNotSupported
    jr halt

MessageNotSupported:
    db "Error: ROM type not supported", 0

.continue_msx32_pletter:        ; Continue loading MSX 32 kB ROM
#if EXEROM_DISABLE=0 
    call PSG_show_BIOS_ROM
    call EXEROM_32KB_PL_PART1   ; MSX loader: 32 kB ROM-file first part (packed with Pletter)
    jr continue_msx32
#endif

.continue_msx32_zx0:            ; Continue loading MSX 32 kB ROM packed with ZX0
#if EXEROM_DISABLE=0 
    ld hl, (GameCompressedAddress)
    ld de, (GameLoadAddress)
    call DZX0_ADDRESS

    call PSG_show_BIOS_ROM
    call EXEROM_32KB_RAW_PART1  ; MSX loader: 32 kB ROM-file first part (now unpacked)
.continue_msx32:
    call PSG_disable_CART_enable_BK21

    ld de, SelectedGameData     ; Use the second game data
    ld hl, SelectedGameData + SelectedGameDataLength
    ld bc, SelectedGameDataLength
    ldir

    jp load_another_part
#endif

.finish_msx32_zx0:              ; Finish loading MSX 32 kB ROM packed with ZX0
#if EXEROM_DISABLE=0 
    ld hl, (GameCompressedAddress)
    ld de, (GameLoadAddress)
    call DZX0_ADDRESS
    call PSG_show_BIOS_ROM      ; For some reason, the uncompressed loader requires the BIOS ROM to be visible in part 2 (Pletter version does not)
    jp EXEROM_32KB_RAW_PART2    ; MSX loader: 32 kB ROM-file first part (now unpacked)
#endif

.msx16_zx0_loader               ; Load 16 kBM MSX ROM packed with ZX0
#if EXEROM_DISABLE=0 
    ld hl, (GameCompressedAddress)
    ld de, (GameLoadAddress)
    call DZX0_ADDRESS
    call PSG_show_BIOS_ROM      ; For some reason, the uncompressed loader requires the BIOS ROM to be visible in part 2 (Pletter does not)
    jp EXEROM_16KB_RAW          ; MSX loader: 32 kB ROM-file first part (now unpacked)
#endif

.continue_rom48_zx0:            ; Part 1
    call PSG_disable_CART_enable_BK21

    ld hl, GAME_DATA_STORAGE
    ld de, (GameLoadAddress)
    call DZX0_ADDRESS           ; Decompress the first part to lower bank

    ld de, SelectedGameData     ; Use the second game data
    ld hl, SelectedGameData + SelectedGameDataLength
    ld bc, SelectedGameDataLength
    ldir

    jp load_another_part

.finish_rom48_zx0:              ; Part 2
    call PSG_disable_CART_enable_BK21

    ld hl, (GameJumpAddress)
    push hl
    ld hl, (GameCompressedAddress)
    ld de, (GameLoadAddress)
    jp DZX0_ADDRESS             ; Decompress the first part to lower bank, and then ret to game jump address

.loader_rom_48_zx0
    call PSG_disable_CART_enable_BK21

    ld hl, (GameJumpAddress)
    push hl
    ld hl, GAME_DATA_STORAGE
    ld de, (GameLoadAddress)
BREAKPOINT1:
    jp DZX0_ADDRESS             ; Decompress the first part to lower bank, and then ret to game jump address

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Function and constant definitions

    include "launcher/svi_bios.inc"

; Function to print a zero-terminated string using SVI_ROM_CHPUT

PrintString:
    ld a, (hl)			
    or a
    ret z
    inc hl
    call SVI_ROM_CHPUT
    jr PrintString

; Function to print a single-line zero-terminated string using direct VRAM access in text mode

PrintStringVRAM:
    ld a, e                     ; VDP start address low bits
    out (VDP_ADDRESS_REGISTER), a
    ld a, d                     ; High bits of the start address
    or a, 0x40     			    ; Write to VRAM
    out (VDP_ADDRESS_REGISTER), a

    ld b, 0
.print_string_vram_loop
    ld a, (hl)
    or a
    ret z
    sub a, 32                   ; Pattern table differs 32 from ASCII
    out (VDP_DATA_WRITE), a
    inc hl
    inc b
    jr print_string_vram_loop

PrintCharVRAM:
    push af
    ld a, e                     ; VDP start address low bits
    out (VDP_ADDRESS_REGISTER), a
    ld a, d                     ; High bits of the start address
    or a, 0x40     			    ; Write to VRAM
    out (VDP_ADDRESS_REGISTER), a
    pop af
    sub a, 32
    out (VDP_DATA_WRITE), a
    ret    

    include "launcher/psg.asm"
    include "launcher/fast_ldir.asm"

#if CHECK_CRC=1
    include "launcher/crc16.asm"
#endif

; -----------------------------------------------------------------------------

MessageErrorTooEarly:
    db "Error: sectors are rotating too fast!"
    db 0

; Place information about the selected game at LAUNCHER_ADDRESS (will overwrite code)

SelectedGameData        equ LAUNCHER_ADDRESS ; These need to be in same order than in gamedata.asm, will overwrite launcher from the start
GameType                equ SelectedGameData                       
GameStartSector         equ SelectedGameData + 1
GameLoadAddress         equ SelectedGameData + 2
GameJumpAddress         equ SelectedGameData + 4
GameCompressedAddress   equ SelectedGameData + 6
GameIndex               equ SelectedGameData + 8
GameSizeFirstSector     equ SelectedGameData + 10
GameSizeSecondSector    equ SelectedGameData + 12
GameSizeThirdSector     equ SelectedGameData + 14
#if CHECK_CRC=1
GameCRC16               equ SelectedGameData + 16
SelectedGameDataLength  equ 18
#else
SelectedGameDataLength  equ 16
#endif


GAME_DATA_STORAGE:              ; Starting address for 16 kB of game data temporary storage (overwrites splash, launcher, GameDataTable and EXEROM)

    include "launcher/splash.asm"
    include "launcher/game_selector.asm"

GameDataTable:
    include "build/gamedata.asm"

NUMBER_OF_GAMES         equ (Game1Data - GameDataTable - 2) / 2

#if EXEROM_DISABLE=0
EXEROM:
    binary "MSX/EXEROM"         ; MSX ROM-loader for SVI-328 1.5 - NYYRIKKI

EXEROM_LENGTH           equ $ - EXEROM

EXEROM_SOURCE_ADDRESS   equ EXEROM + 6
EXEROM_TARGET_ADDRESS   equ 0xb1b5
EXEROM_COPY_LENGTH      equ EXEROM_LENGTH - 7
EXEROM_INITIALIZE       equ 0xd0e7
EXEROM_32KB_PL_PART1    equ 0xd014
EXEROM_32KB_PL_PART2    equ 0xd01c
EXEROM_32KB_RAW_PART1   equ 0xd010
EXEROM_32KB_RAW_PART2   equ 0xd018
EXEROM_16KB_RAW         equ 0xd008

#endif
