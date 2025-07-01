;Because this code is pure evil 😈

;Calculates the current tilemap y pos given the current scanline
;1: scanline
macro calc_tilemap_y_pos
    if \1 < 0 || \1 > 135
        fail "Invalid scanline value 👿"
    elif \1 < 64
        ;Lines 0-63
        ;129 + mod(30x,128)
        def tilemapYPos = (129 + (30*(\1) % 128))
    elif \1 < 72
        ;Lines 64-71 (smiley face)
        ;This ends up making the smiley face be rendered using
        ;a different line from the consecutive smiley face tiles
        ;in the middle column.
        ;8 + mod(9x, 64)
        def tilemapYPos = (8 + (9*(\1) % 64))
    else
        ;Lines 72-135
        ;129 + mod(10x,128)
        def tilemapYPos = (129 + (10*(\1) % 128))
    endc
endm

;Updates the scroll y for this scanline by determining
;the tilemap y position, then adjusting it by the current scanline.
;1: scanline
macro update_scroll_y
    ;Calculate the tilemap y position
    calc_tilemap_y_pos \1
    ;Offset it by the current scanline, wrapping around it needed
    def scrollY = (tilemapYPos - \1) % 256
    ;Update the scroll y register
    ld a, scrollY ;4 cycles
    ldh [rSCY], a ;12 cycles
endm


;Macro used every scanline to set y scroll and manipulate the LCDC register while drawing.
;1: scanline
macro draw_scanline
    ld a, \1
    ldh [rLYC], a ;Set the line y compare register
    xor a
    ldh [rIF], a ;Zero out the IF register to reset previous STAT interrupt requests (also prevents halt bug!)
    ;Halt until a STAT interrupt is requested (LY == LYC)
    halt ;4 cycles for wakeup
    nop ;4 cycles

    ;Calculate the new scroll y position for this scanline such that the y position that gets
    ;used for the tilemap pixel fetches matches what gets calculated in calc_tilemap_y_pos.
    update_scroll_y \1 ;16 cycles

    ;At this point 24 cycles have passed since the start of OAM scan, so delay an extra 68
    ;for the 56 remaining cycles of OAM scan, and the first 12 of the drawing mode.
    rept 17
        nop
    endr

    ;We're now at the start of mode 3 after the initial tile fetches. The first time this macro is used
    ;on the first scanline, the LCDC flags will use the set in register c. Otherwise, the LCDC flags
    ;will be the set from b, as set at the bottom of this macro. hl contains LCDC, and bc/de contain the
    ;LCDC flag sets.

    ;This code repeatedly update the LCDC register flags to change what will be drawn for different
    ;8 pixel rows in the scanline. Each load takes 8 cycles, which corresponds directly with the time
    ;the FIFO takes to push an entire row of 8 pixels. However, the test purposefully positions OAM
    ;objects in certain locations, as well as toggles the window on/off to affect the timing of when
    ;specific pixels are pushed, which can impact how these writes line up with the pixel fetcher/FIFO.
    ;(TODO: research more about how the FIFO/pixel fetcher delays from OAM/window impact this code.)

    ;The following LCDC flags are constant: BG tilemap: 0, OBJ size: 8
    ;Everything else (window tilemap, window/obj enable, tile data area, BG priority) varies based
    ;on the flags used.

    ;If on the first scanline, c flags are used initially:
    ;Window on, obj on, window tilemap 1, tile data area 1, bg priority on
    ;Otherwise, b flags are used initially:
    ;Window on, obj on, window tilemap 1, tile data area 0, bg priority on

    ;16 loads -> 128 cycles (8 cycles each)
    ld [hl], d ;Window off, obj off, window tilemap 0, tile data area 0, bg priority off
    ld [hl], e ;Window on, obj off, window tilemap 1, tile data area 0, bg priority on
    ld [hl], d ;Window off, obj off, window tilemap 0, tile data area 0, bg priority off
    ld [hl], b ;Window on, obj on, window tilemap 1, tile data area 0, bg priority on
    ld [hl], c ;Window on, obj on, window tilemap 1, tile data area 1, bg priority on
    ld [hl], d ;Window off, obj off, window tilemap 0, tile data area 0, bg priority off
    ld [hl], e ;Window on, obj off, window tilemap 1, tile data area 0, bg priority on
    ld [hl], d ;Window off, obj off, window tilemap 0, tile data area 0, bg priority off
    ld [hl], c ;Window on, obj on, window tilemap 1, tile data area 1, bg priority on
    ld [hl], b ;Window on, obj on, window tilemap 1, tile data area 0, bg priority on
    ld [hl], c ;Window on, obj on, window tilemap 1, tile data area 1, bg priority on
    ld [hl], d ;Window off, obj off, window tilemap 0, tile data area 0, bg priority off
    ld [hl], e ;Window on, obj off, window tilemap 1, tile data area 0, bg priority on
    ld [hl], d ;Window off, obj off, window tilemap 0, tile data area 0, bg priority off
    ld [hl], c ;Window on, obj on, window tilemap 1, tile data area 1, bg priority on
    ld [hl], b ;Window on, obj on, window tilemap 1, tile data area 0, bg priority on
endm