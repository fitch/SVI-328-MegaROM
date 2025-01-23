;******************************************************************************
; Spectravideo SVI-328 MegaROM
; (c) 2025 Markus Rautopuro
; 
; Use z88dk to compile, type 'make', see 'makefile' for details.
;

ShowGameSelector:
	call SVI_ROM_ERAFNK         ; Disable function key line in text mode
	call SVI_ROM_INITXT         ; Initialize text mode

    di

	xor a                       ; Hide cursor
	ld (SVI_RAM_CURSOR_STATUS), a

.redraw:
    ld de, 0                    ; Coordinate (0,0)
    PrintVRAM MessageSelect

    ld a, (GamePages)
    cp 1
    jr z, skip_message

    ld de, 20 + 21 * 40
    PrintVRAM MessageChangePage

.skip_message
    ld hl, GamePageData
    ld a, (SelectedPage)
    ld b, a
    add a, a
    add a, b
    ld e, a
    ld d, 0
    add hl, de

    ld a, (hl)                  ; Game count on selected page
    ld (GameCount), a
    inc hl

    ld a, (hl)                  ; Game names
    inc hl
    ld h, (hl)
    ld l, a

.print_games:
    ld b, 65                    ; Game A (first game)
    ld de, 0 + 1 * 40           ; Coordinate (0,1)
.loop_and_print_games:
    push bc
    push de

    ld a, b
    cp a, 91
    jr c, letters
    sub a, 43                   ; Display numbers when letters run out
.letters:
    call PrintCharVRAM
    inc de
    inc de
    call PrintStringVRAM
    inc hl
    
    pop de
    push hl

    ld hl, 40                   ; Next line
    add hl, de
    ld de, hl

    pop hl 
    pop bc

    inc b

    ld a, (GameCount)
    add a, 65
    cp b
    jr z, proceed

    ld a, b
    cp 21 + 65                  ; Print only 22 lines and then next column
    jr nz, loop_and_print_games

    ld de, 20 + 1 * 40          ; Print the second column, start from (20, 1)
    jr loop_and_print_games

.proceed:
.wait_choosing_valid_game:
    ei
    call SVI_ROM_CHGET
    di

    cp 32                       ; Check <space>
    jr z, next_page
    sub a, 48                   ; Check if user pressed 0-9
    cp 11
    jr nc, did_not_press_number
    add a, 26                   ; 0 is the 26th game
    jr check_if_valid_game

.did_not_press_number:
    sub a, 65 - 48              ; Check A-...
    cp 26
    jr nc, did_not_press_hicase
    jr check_if_valid_game

.did_not_press_hicase:
    sub a, 97 - 65              ; Check a-...
    cp 26
    jr nc, wait_choosing_valid_game

.check_if_valid_game:
    push af
    ld a, (GameCount)
    ld b, a
    pop af
    cp b
    jr nc, wait_choosing_valid_game

.game_selected:
    ld de, 0 + 23 * 40          ; Print to bottom left corner
    push af
    add a, 65
    cp a, 91                    ; "Z" + 1
    jr c, print_character
    sub a, 43                   ; "Z" + 1 -> "0"
.print_character
    ld (SelectedGameCharacter), a
    PrintVRAM MessageLoading    ; Print message to load the selected game

    ld a, (SelectedPageIndex)
    ld b, a
    pop af

    add a, b
    ret

.next_page:
    ld a, (GameCount)
    ld b, a
    ld a, (SelectedPageIndex)
    add a, b
    ld (SelectedPageIndex), a
    
    ld a, (GamePages)
    ld b, a

    ld a, (SelectedPage)
    inc a
    cp b
    jr c, next_page_continue
    xor a
    ld (SelectedPageIndex), a

.next_page_continue:
    ld (SelectedPage), a

    call SVI_ROM_CLS
    jp redraw

GameCount:
    db 0

SelectedPage:
    db 0

SelectedPageIndex:
    db 0

MessageSelect:
	db "Select game:", 0

MessageChangePage:
    db "<space> next page", 0

MessageLoading:
    db "Loading game "
SelectedGameCharacter:
    db 0
    db "...", 0
