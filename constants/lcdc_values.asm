;Sets of LCDC flags used for the complex rendering via mid-scanline
;LCDC register writes.

;Creates a definition for a set of LCDC flags.
;LCDC enable is always 1, the bg tilemap is always 0, and obj size is always 0 (8x8)
;1: name
;2: lcdc window tilemap flag (bit 6)
;3: lcdc window enable flag (bit 5)
;4: lcdc tile data area flag (bit 4)
;5: lcdc sprites enable flag (bit 1)
;6: lcdc bg priority (bit 0)
MACRO lcdc_flags
    def \1 equ \
    (1 << B_LCDC_ENABLE) | (\2 << B_LCDC_WIN_MAP) | (\3 << B_LCDC_WINDOW) \
    | (\4 << B_LCDC_BLOCKS) | (0 << B_LCDC_BG_MAP) | (0 << B_LCDC_OBJ_SIZE) \
    | (\5 << B_LCDC_OBJS) | (\6 << B_LCDC_PRIO)
ENDM

;Flag table:
;   | Win Tilemap | Win Enable | Tile Area | BG Tilemap | OBJ size | OBJ enable | BG Priority
;--------------------------------------------------------------------------------------------
; B |      1      |     on     |     0     |      0     |     8    |     on     |     on
; C |      1      |     on     |     1     |      0     |     8    |     on     |     on
; D |      0      |     off    |     0     |      0     |     8    |     off    |     off
; E |      1      |     on     |     0     |      0     |     8    |     off    |     on

lcdc_flags LCDC_FLAGS_TILE_AREA_0, 1, 1, 0, 1, 1 ;0xe3, B
lcdc_flags LCDC_FLAGS_TILE_AREA_1, 1, 1, 1, 1, 1 ;0xf3, C
lcdc_flags LCDC_FLAGS_DISABLE_WIN_OBJ, 0, 0, 0, 0, 0 ;0x80, D
lcdc_flags LCDC_FLAGS_DISABLE_OBJ, 1, 1, 0, 0, 1 ;0xe1, E