;This area is normally reserved for reset vector code, but is instead
;repurposed for different functions, with the portion reserved for interrupt handlers
;being completely blank (nop instructions). While normally this would be very problematic,
;but since both interrupts or reset vectors are disabled, this doesn't cause issues. We
;don't do things normally around here 😈

SECTION "RST Vectors", ROM0[$0000]

;0x0
;b: length
;hl: data address
;a: start index
UpdateGBCBGPaletteData:
    ;Enable auto increment
    or BGPI_AUTOINC
    ldh [rBGPI], a
    ld c, LOW(rBGPD)
.loop
    ld a, [hl+]
    ldh [c], a
    dec b
    jr nz, .loop
    ret

;0xc
;b: length
;hl: data address
;a: start index
UpdateGBCOBJPaletteData:
    ;Enable auto increment
    or OBPI_AUTOINC
    ldh [rOBPI], a
    ld c, LOW(rOBPD)
.loop
    ld a, [hl+]
    ldh [c], a
    dec b
    jr nz, .loop
    ret

;0x18
;a: fill byte, bc: length, hl: destination address
;Fills bc bytes at hl with a.
SetMem16:
    ld d, a
.loop
    ld [hl+], a
    dec bc
    ld a, b
    or c
    ld a, d
    jr nz, .loop
    ret

;0x21
CheckLCDStatus:
    ld hl, rLCDC
    bit B_LCDC_ENABLE, [hl]
    ret z ;return if the LCD is off
    ;Wait for vblank, then turn the LCD off
    call WaitForVBlank
    res B_LCDC_ENABLE, [hl]
    ret

;0x2d
WaitForVBlank:
    ldh a, [rLY]
    cp $90 ;are we at vblank?
    jr nz, WaitForVBlank ;keep looping if not
    ret


;0x34
;hl: source address, de: destination address, bc: length
;Copies bc bytes from hl to de.
CopyMem:
.loop
    ld a, [hl+]
    ld [de], a
    inc de
    dec bc
    ld a, b
    or c
    jr nz, .loop
    ret

SECTION "Header", ROM0[$0100]

;0x100
;Entry point.
Start:
    nop
    jp _Start

    ;Reserve space for header
    ds $0150 - @

ENDSECTION
