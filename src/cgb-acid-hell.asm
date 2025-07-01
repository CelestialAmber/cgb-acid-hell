;0x150
;Start function in main code that is jumped to from entry point
_Start:
    di ;Permanently turn off interrupts b/c we don't need them 😈
    ld sp, STACK_START_ADDR
    push af
    ;Check if the LCD is on right now. If it is, wait for vblank, then
    ;turn it off.
    call CheckLCDStatus
    pop af
    cp BOOTUP_A_CGB ;Are we on GBC? (a == 0x11)
    jp nz, HandleNonGBC ;If not, jump to the sorry message screen
    ;Fill OAM with 0xFF
    xor a
    ld [wFrameCount], a
    ld hl, OAM_START
    ld bc, OAM_SIZE
    ld a, $ff
    call SetMem16
    ;Copies 0xA0 bytes starting from index 1 of the tilemap 0 data to OAM.
    ;This part of the tilemap is specially crafted to double as OAM, which
    ;will impact how the scanline rendering in the test works.
    ld hl, TilemapData+1
    ld de, OAM_START
    ld bc, OAM_SIZE
    call CopyMem
    ;Copy GBC background/object palette data (same 3 palettes for each)
    ld hl, GBCPaletteData
    ld b, PAL_SIZE*3
    xor a
    call UpdateGBCBGPaletteData
    ld hl, GBCPaletteData
    ld b, PAL_SIZE*3
    xor a
    call UpdateGBCOBJPaletteData
    ;Test unused OAM behavior. If the test fails, jump to the sorry message screen.
    call TestUnusedOAMMemory
    ;Initialize VRAM
    ;Switch to VRAM bank 1
    ld a, 1
    ldh [rVBK], a
    ;Copy the credits message to VRAM bank 1, starting at tile 16 in block 2
    ld hl, CreditsMessageGraphicsData
    tileaddr de, 2, MESSAGE_START_TILE_INDEX
    ld bc, MESSAGE_GRAPHICS_SIZE
    call CopyMem
    ;Setup attribute map 1 for the bottom message
    ld hl, TILEMAP1
    ld a, BG_BANK1 | 2 ;use bank 1, palette 2
    ld c, TOTAL_MESSAGE_TILES
.initAttrMap1Loop
    ld [hl+], a
    dec c
    jr nz, .initAttrMap1Loop
    ;Initialize attribute map for tilemap 0, making only the first tile in every row visible
    ld a, BG_BANK0 | 1 ;use bank 0, palette 1
    ld hl, TILEMAP0
    ld bc, TILEMAP_WIDTH*TILEMAP_HEIGHT
    push hl
    call SetMem16
    ;Load the flags in d, and the tilemap width in e
    ld de, ((BG_BANK0 | 0) << 8) | TILEMAP_WIDTH
    ld c, TILEMAP_WIDTH/2
    pop hl
.adjustAttrMap0Loop
    ld [hl], d
    add hl, de
    dec c
    jr nz, .adjustAttrMap0Loop
    ;Switch back to vram bank 0
    xor a
    ldh [rVBK], a
    ;Copy tilemap 0 data
    ld hl, TilemapData
    ld de, TILEMAP0
    ld bc, TILEMAP_WIDTH*TILEMAP_HEIGHT
    call CopyMem
    ;Setup tilemap 1 for the bottom message
    ld hl, TILEMAP1
    ld a, MESSAGE_START_TILE_INDEX
    ld c, TOTAL_MESSAGE_TILES
.initTilemap1Loop
    ld [hl+], a
    inc a
    dec c
    jr nz, .initTilemap1Loop
    ;Fill all three blocks of vram bank 0 tile data with 255 copies
    ;of the blank face tile, excluding the first tile (0x8010-0x97FF).
    ;This is done in two steps because of counter limitations.
    ;Fill the first two blocks
    ld c, $ff
    tileaddr de, 0, 1
.initBank0TileDataLoop1
    push bc
    ld hl, BlankFaceGraphicsData
    ld bc, TILE_SIZE
    call CopyMem
    pop bc
    dec c
    jr nz, .initBank0TileDataLoop1
    ;Fill the third block
    ld c, $7f
    tileaddr de, 2, 1
.initBank0TileDataLoop2
    push bc
    ld hl, BlankFaceGraphicsData
    ld bc, TILE_SIZE
    call CopyMem
    pop bc
    dec c
    jr nz, .initBank0TileDataLoop2
    ;Finally, copy the happy face tile to tile 0x69 within block 0. This doesn't
    ;seem to actually get used, as the test renders the smiley face
    ;in another, much more indirect way.
    ld hl, HappyFaceGraphicsData
    tileaddr de, 0, $69
    ld bc, TILE_SIZE
    call CopyMem
    ;Set the STAT register to only allow LYC based STAT interrupts
    ld a, STAT_LYC
    ldh [rSTAT], a
    ;Initialize x scroll, and the window position
    ;Set x scroll so that the face will appear at the right position
    ld a, TILEMAP_WIDTH_PX - FACE_X
    ldh [rSCX], a
    ;Set the window at the bottom where the message graphics will appear
    ld a, MESSAGE_X
    ldh [rWX], a
    ld a, MESSAGE_Y
    ldh [rWY], a
    xor a
    ldh [rLYC], a ;Set the line y compare register to 0 for later
    ldh [rIF], a ;Reset the IF register to clear requested interrupts
    ;Only allow STAT interrupts to be handled
    ld a, IF_STAT
    ldh [rIE], a
    ;Initialize hl with the address for the LCDC register, d/e/b/c with
    ;sets of flag values that will be used later, and set LCDC to the flags
    ;in c.
    ld hl, rLCDC
    ld de, (LCDC_FLAGS_DISABLE_WIN_OBJ << 8) | LCDC_FLAGS_DISABLE_OBJ ;$80e1
    ld bc, (LCDC_FLAGS_TILE_AREA_0 << 8) | LCDC_FLAGS_TILE_AREA_1 ;$e3f3
    ld [hl], c ;Initialize LCDC with the c register flags. This also turns the LCD back on.
    ;fallthrough

;Instead of the regular sane approach to drawing graphics, this code forgoes that entirely to
;manually adjust the y scroll on each scanline and repeatedly change the LCDC flags to control what
;graphics are drawn from the tilemaps and objects. It does this by setting LYC and IF to 0, then halting;
;this causes a STAT interrupt, but no interrupt code is actually called, so the CPU resumes after the halt
;right at the start of the scanline. It then sets SCY such that the Game Boy will draw a specific line of the
;tilemap, and afterwards delays enough cycles until the drawing mode. Once reached, it continuously changes the
;LCDC register flags to change what will be rendered at different parts of the scanline. This is then repeated
;until scanline 135, where afterwards the bottom message will be drawn normally. Most would call this reprehensive
;but we don't use normal graphics rendering here 😈
MainLoop:
    ;Wait for vblank
    call WaitForVBlank
    ;Increment the frame count, and reset it for every 16 frames. Why is this done?
    ld a, [wFrameCount]
    inc a
    cp 10
    jr nz, .skipReset
    xor a
    ld b, b ;sets flags???
.skipReset
    ld [wFrameCount], a
    ;The first iteration will wait until the first scanline through the
    ;STAT interrupt request with LYC.
    for n, 136
        draw_scanline n
    endr
    jp MainLoop ;Jump back to the start


;Bro thought they could run this on a Game Boy 😭💀
HandleNonGBC:
    jp DisplaySorryMessage ;Display the sorry message


;This function tests the behavior of the unused OAM memory region (FEA0-FEFF),
;specifically for how read/writes behave. What actually gets returned depends on
;the hardware, but it should be something other than the test values used. If the
;value written at FEA0 can be read back, the test fails, and the sorry message is
;shown.
;While this could trigger the OAM bug on the original GB, the GBC test before
;prevents a non GBC system from getting here, so this doesn't cause corruption.
TestUnusedOAMMemory:
    ;Try writing a test value at address FEA0 (should not get written)
    ld hl, OAM_START + OAM_SIZE
    ld b, $55
    ;Wait for OAM scan to start
.oamScanWait1
    ldh a, [rSTAT]
    and STAT_BUSY
    jr nz, .oamScanWait1
    ld [hl], b
    ;Try writing a second test value at address FEB8 (also should not get written)
    ld hl, OAM_START + OAM_SIZE + $18
    ld b, $44
    ;Wait for OAM scan to start
.oamScanWait2
    ldh a, [rSTAT]
    and STAT_BUSY
    jr nz, .oamScanWait2
    ld [hl], b
    ;Check if the byte written to FEA0 can be read back (should return something
    ;else regardless of hardware)
    ld hl, OAM_START + OAM_SIZE
    ;Wait for OAM scan to start
.oamScanWait3
    ldh a, [rSTAT]
    and STAT_BUSY
    jr nz, .oamScanWait3
    ld a, [hl]
    cp $55 ;Did the value get stored at FEA0?
    ret nz ;No, the test succeeded
    ;Otherwise, fallthrough to the sorry message code

;This function prints the text "Sorry you don't get to play" at the bottom, and then
;loops indefinitely. This gets called if one of the two initial tests fails (not on GBC
;or inaccurate unused OAM memory implementation)
DisplaySorryMessage:
    ld a, 1
    ldh [rVBK], a ;Set the vram bank to 1 (does nothing on non-GBC)
    ;Copy the sorry message
    ld hl, SorryMessageGraphicsData
    tileaddr de, 2, MESSAGE_START_TILE_INDEX
    ld bc, MESSAGE_GRAPHICS_SIZE
    call CopyMem
    ;Setup attribute map 1 for the bottom message (will get replaced later if not on GBC)
    ld hl, TILEMAP1
    ld a, BG_BANK1 | 2
    ld c, TOTAL_MESSAGE_TILES
.initAttrMap1Loop
    ld [hl+], a
    dec c
    jr nz, .initAttrMap1Loop
    ;Fill attribute map 0 on GBC/tilemap 0 otherwise with 0x01
    ld a, BG_BANK0 | 1
    ld hl, TILEMAP0
    ld bc, TILEMAP_WIDTH*TILEMAP_HEIGHT
    push hl
    call SetMem16
    ;Switch to bank 0 (does nothing on non-GBC)
    xor a
    ldh [rVBK], a
    ;Fill tilemap 0 with zero
    ld hl, TILEMAP0
    ld a, 0
    ld bc, TILEMAP_WIDTH*TILEMAP_HEIGHT
    call SetMem16
    ;Setup tilemap 1 for the bottom message
    ld hl, TILEMAP1
    ld a, MESSAGE_START_TILE_INDEX
    ld c, TOTAL_MESSAGE_TILES
.initTilemap1Loop
    ld [hl+], a
    inc a
    dec c
    jr nz, .initTilemap1Loop
    ;Position the window to display the message at the bottom
    ld a, MESSAGE_X
    ldh [rWX], a
    ld a, MESSAGE_Y
    ldh [rWY], a
    ;Use the e flags for rendering
    ld hl, rLCDC
    ld b, LCDC_FLAGS_DISABLE_OBJ
    ld [hl], b
    ;Loop indefinitely
.infiniteLoop
    jr .infiniteLoop


;Graphics data

;0x1b2c
;gbc palette data (bg and obj palettes)
GBCPaletteData:
;palette 0
RGB 31, 31, 31
RGB 31, 31, 0
RGB 0, 0, 0
RGB 0, 0, 0
;palette 1
RGB 31, 31, 31
RGB 31, 31, 31
RGB 31, 31, 31
RGB 31, 31, 31
;palette 2
RGB 31, 31, 31
RGB 31, 31, 31
RGB 31, 31, 31
RGB 0, 0, 0

;0x1b44
;...xxx..
;..x---x.
;.x-x-x-x
;.x-----x
;.x-xxx-x
;.x-----x
;..x---x.
;...xxx..
BlankFaceGraphicsData:
INCBIN "gfx/blank_face.2bpp"

;0x1b54
;...xxx..
;..x---x.
;.x-x-x-x
;.x-----x
;.x-x-x-x
;.x--x--x
;..x---x.
;...xxx..
HappyFaceGraphicsData:
INCBIN "gfx/happy_face.2bpp"

;0x1b64
TilemapData:
INCBIN "gfx/tilemap.bin"

;0x1f64
;"CGB-ACID-HELL BY MATT CURRIE"
CreditsMessageGraphicsData:
INCBIN "gfx/credits_message.2bpp"

;0x2044
;"SORRY YOU DON'T GET TO PLAY"
SorryMessageGraphicsData:
INCBIN "gfx/sorry_message.2bpp"
