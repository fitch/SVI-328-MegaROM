;******************************************************************************
; Spectravideo SVI-328 MegaROM
; (c) 2025 Markus Rautopuro
; 
; Use z88dk to compile, type 'make', see 'makefile' for details.
;

; Function to calculate a CRC16 checksum of the target area
; https://tomdalby.com/other/crc.html
;
; de = start of memory to check
; bc = byte count
; returns: hl = result CRC

Calculate_CRC16:
    ld hl, 0xffff               ; 10t - initial crc=$ffff
.byte16:
    push bc                     ; 11t - preserve counter
    ld a, (de)                  ; 7t - get byte
    inc de                      ; 6t - next mem
    xor h                       ; 4t - xor byte into crc high byte
    ld h, a                     ; 4t - back into high byte
    ld b, 8                     ; 7t - rotate 8 bits
.rotate16:
    add hl, hl                  ; 11t - rotate crc left one
    jr nc, nextbit16            ; 12/7t - only xor polyonimal if msb set
    ld a, h                     ; 4t
    xor 0x10                    ; 7t - high byte with $10
    ld h, a                     ; 4t
    ld a, l                     ; 4t
    xor 0x21                    ; 7t - low byte with $21
    ld l, a                     ; 4t - hl now xor $1021
.nextbit16:
    djnz rotate16               ; 13/8t - loop over 8 bits
    pop bc                      ; 10t - bring back main counter
    dec bc                      ; 6t
    ld a, b                     ; 4t
    or c                        ; 4t
    jr nz, byte16               ; 12/7t
    ret                         ; 10t

; Function to verify the memory against the stored game CRC16
;
; de = start of memory to check
; bc = byte count

Verify_Game_CRC16:
    call Calculate_CRC16

    ld de, (GameCRC16)
    ld a, h
    cp d
    jr nz, crc_mismatch

    ld a, l
    cp e
    jr nz, crc_mismatch

    ret

.crc_mismatch
    PrintVRAM MessageCRCMismatch
    di
    halt

MessageCRCMismatch:
    db "Error: CRC16 verification error, check hardware or the checksum!"
    db 0
