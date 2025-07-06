;0x150
;Start function in main code that is jumped to from entry point
_Start:
    di ;Permanently turn off interrupts b/c we don't need them 😈
    ld sp, STACK_ADDR
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
    ld hl, OAM_ADDR
    ld bc, OAM_SIZE
    ld a, $ff
    call SetMem16
if !DEF(DEOBFUSCATE)
    ;Copies 0xA0 bytes starting from index 1 of the tilemap 0 data to OAM.
    ;This part of the tilemap is specially crafted to double as OAM, which
    ;will impact how the scanline rendering in the test works.
    ld hl, TilemapData+1
    ld de, OAM_ADDR
    ld bc, OAM_SIZE
else
    ;Only load the data for the single sprite that is used to trigger the
    ;LCDC bit 4 bug on the smiley face scanlines
    ld hl, OAMData
    ld de, OAM_ADDR
    ld bc, OAMDataLength
endc
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
    ;Test whether we're on a system other than CGB-D by checking OAM behavior, and jump to the sorry
    ;message screen if not. This is done as the bugs in the PPU this test relies on work
    ;differently on CGB-D, preventing the test from working properly.
    call CheckIfNotOnCGBD
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
    ;Finally, copy the happy face tile to tile 0x69 within block 0. This is merely a red herring
    ;to trip up people, as we render the smiley face in another, much more indirect way. 😈
    ld hl, HappyFaceGraphicsData
    tileaddr de, 0, SMILEY_FACE_TILE_INDEX
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
if !DEF(DEOBFUSCATE)
    ld [hl], c ;Initialize LCDC with the c register flags. This also turns the LCD back on.
else
    ;Instead use b for consistency/to work with the cleaned code
    ld [hl], b
endc
    ;fallthrough

;This is where the fun happens 😈
MainLoop:
    ;Wait for vblank
    call WaitForVBlank
    ;This code triggers a ld b,b breakpoint every 10 frames as a way to aid with debugging.
    ld a, [wFrameCount]
    inc a
    ;Reset the counter if it reached the max value
    cp 10
    jr nz, .skipReset
    xor a
    ld b, b ;Trigger a breakpoint on emulators that interpret ld b,b as a breakpoint
.skipReset
    ld [wFrameCount], a
    ;Use the manual scanline drawing method until we reach the message y position. The first
    ;iteration will wait until the first scanline through the STAT interrupt request with LYC.
    for n, MANUAL_LINES_NUM
        draw_scanline n
    endr
    jp MainLoop ;Jump back to the start

;Bro thought they could run this on a Game Boy 😭💀
HandleNonGBC:
    jp DisplaySorryMessage ;Display the sorry message


def TEST_VALUE_1 equ $55
def TEST_VALUE_2 equ $44

;This function tests if the system is not a Revision D Game Boy Color by checking the behavior
;of the unused OAM memory region (FEA0-FEFF).
;The behavior depends on the system model as follows:
;CGB (Revision 0-A): Reading/writing uses the given address, but bits 3-4 are masked out (addr & ~0x18)
;CGB (Revision D):
;
;By doing two writes within the masked region, and using values that can't get returned by the
;later models that are based on the address, it makes the test only fail if on CGB-D.
;While this could trigger the OAM bug on the original GB, the GBC test before
;prevents a non GBC system from getting here, so this doesn't cause corruption.
CheckIfNotOnCGBD:
    ;Try writing a test value at address FEA0 (on earlier models, the write works normally; on
    ;later models, it gets ignored)
    ld hl, OAM_UNUSED_ADDR
    ld b, TEST_VALUE_1
    ;Wait for OAM scan to start
.oamScanWait1
    ldh a, [rSTAT]
    and STAT_BUSY
    jr nz, .oamScanWait1
    ld [hl], b
    ;Try writing a second test value at address FEB8. On earlier models, the address should end
    ;up as FEA0 after masking, overwriting the first written byte. On later models, it again
    ;gets ignored. 
    ld hl, OAM_UNUSED_ADDR + $18
    ld b, TEST_VALUE_2
    ;Wait for OAM scan to start
.oamScanWait2
    ldh a, [rSTAT]
    and STAT_BUSY
    jr nz, .oamScanWait2
    ld [hl], b
    ;Check the value at FEA0. On earlier models, it should return the second written byte 0x44,
    ;and on later models it should instead return 0xAA, using the upper nybble of the lower byte.
    ;On CGB-D, however, 
    ld hl, OAM_UNUSED_ADDR
    ;Wait for OAM scan to start
.oamScanWait3
    ldh a, [rSTAT]
    and STAT_BUSY
    jr nz, .oamScanWait3
    ld a, [hl]
    cp TEST_VALUE_1 ;Did only the first value get stored at FEA0?
    ret nz ;No, we're not on a CGB-D system
    ;Otherwise, fallthrough to the sorry message code

;This function prints the text "Sorry you don't get to play" at the bottom, and then
;loops indefinitely. This gets called if one of the two initial tests fails (not on
;GBC/on CGB-D)
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
