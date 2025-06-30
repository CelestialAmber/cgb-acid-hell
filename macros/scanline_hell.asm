;Because this code is pure evil 😈

;Initializes the scanline counter used by the update macro
MACRO def_scanline_counter
    DEF cur_scanline = 0
ENDM

;Macro used every scanline to set y scroll and manipulate the LCDC register while drawing.
;1: y scroll value
MACRO draw_scanline
    ld a, cur_scanline ;Set the current scanline to the current value in the define
    ldh [rLYC], a ;Set the line y compare register
    xor a
    ldh [rIF], a ;Zero out the IF register to reset previous STAT interrupt requests (also prevents halt bug!)
    
    ;The following code halts until a STAT interrupt is requested (LY == LYC), delaying for all 80 cycles of
    ;OAM scan, and the first 12 cycles of mode 3.
    halt ;4 cycles for wakeup
    nop ;4 cycles
    ld a, \1 ;4 cycles
    ldh [rSCY], a ;Set the scroll y register (12 cycles)
    ;Delay for 68 cycles (17 nops).
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

    ;Increment the scanline count define
    DEF cur_scanline += 1
ENDM