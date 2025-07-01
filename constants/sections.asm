;Section address constants

;VRAM addresses
def VRAM_START equ $8000
def VRAM_BLOCK_SIZE equ $800
def VRAM_BLOCK_0 equ VRAM_START
def VRAM_BLOCK_1 equ VRAM_START + VRAM_BLOCK_SIZE
def VRAM_BLOCK_2 equ VRAM_START + VRAM_BLOCK_SIZE*2

;OAM addresses
def OAM_START equ $FE00

;Stack pointer address
def STACK_START_ADDR equ $FFFE
