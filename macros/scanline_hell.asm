;Calculates the current tilemap y pos given the current scanline.
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
    ld a, scrollY ;8 cycles
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
    ;For most scanlines, this will make all the pixels end up being white, with only pixels
    ;on scanlines 64-72 that use the second formula, and specifically from x position 76
    ;ending up being the face tile from the leftmost column that uses the non-white palette.
    ;However, there is a caveat to this which is explained later. 
    update_scroll_y \1 ;20 cycles

    ;At this point 28 cycles have passed since the start of OAM scan, so delay an extra 68
    ;for the 52 remaining cycles of OAM scan, and the first 16 of the drawing mode (2 bg fetches
    ;+ 180 mod 8 = 4 cycles)
    rept 17
        nop
    endr

    ;We're now at the start of mode 3 after the initial tile fetches (plus 4 cycles for the pixel discarding
    ;from scroll). The first time this macro is used on the first scanline, the LCDC flags will use the set
    ;in register c. Otherwise, the LCDC flags will be the set from b, as set at the bottom of this macro.
    ;hl contains LCDC, and bc/de contain the LCDC flag sets.

    ;The following LCDC flags are constant: BG tilemap: 0, OBJ size: 8
    ;Everything else (window tilemap, window/obj enable, tile data area, BG priority) varies based
    ;on the flags used.

    ;If on the first scanline, c flags are used initially:
    ;Window on, obj on, window tilemap 1, tile data area 1, bg priority on
    ;Otherwise, b flags are used initially:
    ;Window on, obj on, window tilemap 1, tile data area 0, bg priority on

    ;We manually update the LCDC bits on every scanline such that on most scanlines (0-62, 72-135),
    ;nothing noticeable happens, even with the other garbage OAM data, while on the scanlines with
    ;the sprite at the left corner of the screen at coordinates (-7, 63), or (1,79) in OAM, an extra
    ;delay of 6 cycles occurs due to it triggering a sprite fetch, which succeeds, but due to the first write
    ;on dot 96, the sprite isn't drawn. This makes it so the writes are aligned such that on dot 172
    ;(first t cycle of the ld [hl] instruction that starts on dot 168), where the top bitplane fetch
    ;happens on scanlines 64-71 for the smiley face tile data, bit 4 of LCDC is reset, which on all systems
    ;except CGB-D will trigger a bug that makes the tile index for that tile be used instead. Since the tile as
    ;explained above is rendered by using a line from several different copies in the first column (tile indices 1-7),
    ;the upper bitplane instead uses their tile indices, which are set such that they have the appropriate pixel data.
    ;
    ;Some things to note:
    ;-On scanline 63, the bug still happens; however, since it maps to a part of the tilemap at y position
    ;which uses the all white palette, nothing ends up looking different.
    ;-The last line of the smiley face is rendered as normal from the indirect SCY method, instead of the
    ;LCDC bit 4 bug method.
    ;
    ;On top of it all, several superfluous LCDC bit updates are done to obfuscate what's happening
    ;for extra fun 😈

if !DEF(DEOBFUSCATE)
    ld [hl], d ;Dot 96: Window off, obj off, window tilemap 0, tile data area 0, bg priority off
    ld [hl], e ;Dot 104: Window on, obj off, window tilemap 1, tile data area 0, bg priority on
    ld [hl], d ;Dot 112: Window off, obj off, window tilemap 0, tile data area 0, bg priority off
    ld [hl], b ;Dot 120: Window on, obj on, window tilemap 1, tile data area 0, bg priority on
    ld [hl], c ;Dot 128: Window on, obj on, window tilemap 1, tile data area 1, bg priority on
    ld [hl], d ;Dot 136: Window off, obj off, window tilemap 0, tile data area 0, bg priority off
    ld [hl], e ;Dot 144: Window on, obj off, window tilemap 1, tile data area 0, bg priority on
    ld [hl], d ;Dot 152: Window off, obj off, window tilemap 0, tile data area 0, bg priority off
    ld [hl], c ;Dot 160: Window on, obj on, window tilemap 1, tile data area 1, bg priority on
    ld [hl], b ;Dot 168: Window on, obj on, window tilemap 1, tile data area 0, bg priority on
    ld [hl], c ;Dot 176: Window on, obj on, window tilemap 1, tile data area 1, bg priority on
    ld [hl], d ;Dot 184: Window off, obj off, window tilemap 0, tile data area 0, bg priority off
    ld [hl], e ;Dot 192: Window on, obj off, window tilemap 1, tile data area 0, bg priority on
    ld [hl], d ;Dot 200: Window off, obj off, window tilemap 0, tile data area 0, bg priority off
    ld [hl], c ;Dot 208: Window on, obj on, window tilemap 1, tile data area 1, bg priority on
    ld [hl], b ;Dot 216: Window on, obj on, window tilemap 1, tile data area 0, bg priority on
else
    ;Simplified version of the above

    ;Reset obj enable on dot 96 to prevent the dummy sprite on scanline 63-71 from rendering,
    ;which sets up timing. On other scanlines, this does nothing of note.
    ld [hl], e
    ;Set obj enable back on and the tile data area to 1
    ld [hl], c
    ;Delay to dot 168, which is when the smiley face will be drawn on scanlines 64-72
    rept 14
        nop
    endr
    ;On dot 168, which should be at x position 74 where the smiley face is drawn on scanlines 64-72, reset the tile
    ;data area flag to trigger the bug, and set obj enable back to on.
    ld [hl], b
endc

endm