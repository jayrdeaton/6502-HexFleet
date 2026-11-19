; =============================================================================
;   vdp.asm - the PICOVDP: setup, loading, text, sprites and the canvas
; =============================================================================
;   Everything that knows about the video hardware lives here, so a port to
;   another machine replaces this file.
;
;   Layer 0 is the board, fixed once loaded. Layer 1 (2 bits per pixel) is both
;   the text and the canvas: its patterns 32..127 are the card's font, and 128..255
;   and up are a pool of tiles the game draws beams, rings, outlines and big text
;   into, handed to cells as they're touched. With 2 bits a pixel, two lasers crossing in one cell
;   each keep their own color. Port A only: the Kernal
;   leaves it alone in interrupts, so no SEI is needed.
; =============================================================================

.segment "CART"

; Register, value pairs for the display setup
VideoRegs:
  .byte VC_REG_MODE1,   $02         ; display off, 16x16 sprites
  .byte VC_REG_MODE0,   $00
  .byte VC_REG_VMODE,   $04         ; Full: 40 x 30, 320 x 240
  .byte VC_REG_VBANK,   0
  .byte VC_REG_VINC,    1
  .byte VC_REG_IRQEN,   0
  .byte VC_REG_STATSEL_A, 0
  .byte VC_REG_COLOR,   $04         ; backdrop: palette row 0, entry 4
  .byte VC_REG_L0NAME,  >V_L0NAME >> 2
  .byte VC_REG_L0PAT,   >V_L0PAT >> 3
  .byte VC_REG_L0SCRX,  0
  .byte VC_REG_L0SCRY,  0
  .byte VC_REG_L0CTRL,  VC_LCTRL_2BPP | VC_LCTRL_ATTR_NONE | VC_LCTRL_ENABLE
  .byte VC_REG_L0PAL,   0
  .byte VC_REG_L1NAME,  >V_L1NAME >> 2
  .byte VC_REG_L1ATTR,  >V_L1ATTR >> 2
  .byte VC_REG_L1PAT,   >V_FONT >> 3    ; the font loads here first
  .byte VC_REG_L1SCRX,  0
  .byte VC_REG_L1SCRY,  0
  .byte VC_REG_L1CTRL,  VC_LCTRL_1BPP | VC_LCTRL_ATTR_CELL | VC_LCTRL_ENABLE
  .byte VC_REG_L1PAL,   3               ; sub-palettes from entry 192
  .byte VC_REG_SPRATTR, >V_SPRATTR << 1
  .byte VC_REG_SPRPAT,  $08         ; $4000
  .byte VC_REG_SPRCOUNT, NUM_SLOTS
  .byte VC_REG_SPRCTRL, VC_SPRCTRL_ENABLE | VC_SPRCTRL_4BPP
  .byte VC_REG_SPRLIMIT, 32
  .byte VC_REG_SPRPAL,  0
VIDEO_REGS = * - VideoRegs

; Palette row 0, entries 1..4: grid, dim star, bright star, backdrop (the app's
; near-black)
PaletteBoard:
  .byte $02, $46,  $03, $45,  $0A, $BD,  $01, $12
; Layer 1's inks, by number
PaletteInks:
  .byte $00, $00,  $01, $12,  $0F, $FF,  $09, $AB
  .byte $03, $AF,  $0F, $92,  $03, $E5,  $0B, $6F
  .byte $00, $EE,  $0F, $44,  $0A, $F3,  $0F, $5D
  .byte $0F, $D3,  $05, $67,  $00, $00,  $00, $00

; Hull bar cells: the top rows filled to 0..8 pixels, a thin line below
BarMasks:
  .byte $00, $80, $C0, $E0, $F0, $F8, $FC, $FE, $FF

RowLo:
.repeat 30, I
  .byte <(I * 40)
.endrepeat
RowHi:
.repeat 30, I
  .byte >(I * 40)
.endrepeat

; A 4-bit pattern as 2-bit pixels of value 1
Nibble2:
  .byte $00, $01, $04, $05, $10, $11, $14, $15
  .byte $40, $41, $44, $45, $50, $51, $54, $55
; The canvas: the bits of a pixel, by column in its byte, and each value there
PixClear:
  .byte $3F, $CF, $F3, $FC
PixBits:
  .byte $00, $00, $00, $00,  $40, $10, $04, $01
  .byte $80, $20, $08, $02,  $C0, $30, $0C, $03
; Where each of a tile's 16 bytes is kept
CtLo:
.repeat 16, I
  .byte <(CT_ROWS + I * 256)
.endrepeat
CtHi:
.repeat 16, I
  .byte >(CT_ROWS + I * 256)
.endrepeat

; SetBank - A selects the 8 KB bank at $C000. Only called from here.
SetBank:
  sta BANKSHDW
  sta BANK
  rts

; VReg - A = value, X = register. Keeps X.
VReg:
  sta VC_REG
  txa
  ora #VC_REG_WRITE
  sta VC_REG
  rts

; VAddr - point port A at A (low), X (high) to write. Keeps X.
VAddr:
  sta VC_REG
  txa
  ora #VC_ADDR_WRITE
  sta VC_REG
  rts

; WaitFrame - until the picture next ends.
WaitFrame:
  bit VC_STATUS                     ; bit 7 is the end-of-frame flag
  bpl WaitFrame
  rts

WaitFrames:
  tax
@loop:
  phx
  jsr WaitFrame
  plx
  dex
  bne @loop
  rts

; CopyVram - T1:T0 bytes from (PTR0) to where the chip points.
CopyVram:
  ldx T1
  beq @tail
  ldy #0
@page:
  lda (PTR0),y
  sta VC_DATA
  iny
  bne @page
  inc PTR0+1
  dex
  bne @page
@tail:
  ldy #0
@last:
  cpy T0
  beq @done
  lda (PTR0),y
  sta VC_DATA
  iny
  bra @last
@done:
  rts

; FillVram - T1:T0 bytes of A where the chip points.
FillVram:
  ldx T1
  beq @tail
  ldy #0
@page:
  sta VC_DATA
  iny
  bne @page
  dex
  bne @page
@tail:
  ldy T0
  beq @done
@last:
  sta VC_DATA
  dey
  bne @last
@done:
  rts

; VideoInit - set the card up and load the board, sprites and font.
VideoInit:
  ldy #0
@regs:
  ldx VideoRegs,y
  lda VideoRegs+1,y
  jsr VReg
  iny
  iny
  cpy #VIDEO_REGS
  bne @regs

  ; The palette lives at $FC00, in the top bank of video memory
  lda #3
  ldx #VC_REG_VBANK
  jsr VReg
  lda #$02
  ldx #$3C
  jsr VAddr
  ldy #0
@board:
  lda PaletteBoard,y
  sta VC_DATA
  iny
  cpy #8
  bne @board
  lda #$A0
  ldx #$3D                          ; sub-palette 4 of the top quarter: $FDA0
  jsr VAddr
  ldy #2
@inks:
  stz VC_DATA                       ; value 0 is never drawn
  stz VC_DATA
  ldx #2
@twice:
  lda PaletteInks,y                 ; values 1 and 2: the ink
  sta VC_DATA
  lda PaletteInks+1,y
  sta VC_DATA
  dex
  bne @twice
  lda PaletteInks+2                 ; value 3: the dark
  sta VC_DATA
  lda PaletteInks+3
  sta VC_DATA
  iny
  iny
  cpy #26
  bne @inks

  ; The sprites, from their bank, to $4000
  lda #1
  ldx #VC_REG_VBANK
  jsr VReg
  lda #2
  jsr SetBank
  lda #0
  tax
  jsr VAddr
  lda #<SpriteData
  sta PTR0
  lda #>SpriteData
  sta PTR0+1
  lda #<(SPRITE_COUNT * 128)
  sta T0
  lda #>(SPRITE_COUNT * 128)
  sta T1
  jsr CopyVram
  lda #0
  ldx #VC_REG_VBANK
  jsr VReg

  ; The board's name table and tiles
  lda #1
  jsr SetBank
  lda #<V_L0NAME
  ldx #>V_L0NAME
  jsr VAddr
  lda #<BoardMap
  sta PTR0
  lda #>BoardMap
  sta PTR0+1
  lda #<1200
  sta T0
  lda #>1200
  sta T1
  jsr CopyVram
  lda #<V_L0PAT
  ldx #>V_L0PAT
  jsr VAddr
  lda #<BoardTiles
  sta PTR0
  lda #>BoardTiles
  sta PTR0+1
  lda #<(BOARD_TILES * 16)
  sta T0
  lda #>(BOARD_TILES * 16)
  sta T1
  jsr CopyVram
  lda #0
  jsr SetBank

  ; The card's own font, loaded where it stays to be read (lands at the frame end)
  lda #$80
  ldx #VC_REG_FONT
  jsr VReg
  lda #3
  jsr WaitFrames
  lda #>V_L1PAT >> 3
  ldx #VC_REG_L1PAT
  jsr VReg
  lda #VC_LCTRL_2BPP | VC_LCTRL_ATTR_CELL | VC_LCTRL_ENABLE
  ldx #VC_REG_L1CTRL
  jsr VReg

  ; Pattern 0 blank, then the hull bar cells over patterns 1..9
  lda #<V_L1PAT
  ldx #>V_L1PAT
  jsr VAddr
  ldx #16
@blank:
  stz VC_DATA
  dex
  bne @blank
  stz RC
@bar:
  lda #0
  jsr PutRow
  lda #0
  jsr PutRow
  ldy RC
  lda BarMasks,y
  jsr PutRow
  ldy RC
  lda BarMasks,y
  jsr PutRow
  ldy RC
  lda BarMasks,y
  jsr PutRow
  lda #0
  jsr PutRow
  ldy RC
  lda BarMasks,y                    ; a dotted line shows the bar's length
  ora #$AA
  jsr PutRow
  lda #0
  jsr PutRow
  inc RC
  lda RC
  cmp #9
  bne @bar
  ldx #16                           ; pattern 10: solid
  lda #$FF
@solid:
  sta VC_DATA
  dex
  bne @solid

  ; The text: the font's characters as 2-bit patterns
  lda #32
  sta RC
@glyph:
  lda RC
  jsr ReadGlyph
  lda RC
  asl a
  asl a
  asl a
  asl a
  pha
  lda RC
  lsr a
  lsr a
  lsr a
  lsr a
  clc
  adc #>V_L1PAT
  tax
  pla
  jsr VAddr
  stz RR
@row:
  ldy RR
  lda GLYPH,y
  jsr PutRow
  inc RR
  lda RR
  cmp #8
  bne @row
  inc RC
  bpl @glyph                        ; through 127

  jsr CanvasReset
  jsr ClearLayer1
  jsr HideSprites
  jsr UploadSprites
  lda #$42                          ; display on, 16x16 sprites
  ldx #VC_REG_MODE1
  jmp VReg

; PutRow - a row of 8 one-bit pixels, A, as 2-bit pixels of value 1.
PutRow:
  pha
  lsr a
  lsr a
  lsr a
  lsr a
  tax
  lda Nibble2,x
  sta VC_DATA
  pla
  and #$0F
  tax
  lda Nibble2,x
  sta VC_DATA
  rts

; CanvasColors - the canvas's values 1 and 2 become the two ships' inks.
CanvasColors:
  lda #3
  ldx #VC_REG_VBANK
  jsr VReg
  lda #$A2
  ldx #$3D
  jsr VAddr
  ldx #0
@ship:
  lda SHIP_INK,x
  asl a
  tay
  lda PaletteInks,y
  sta VC_DATA
  lda PaletteInks+1,y
  sta VC_DATA
  inx
  cpx #NUM_SHIPS
  bne @ship
  lda #0
  ldx #VC_REG_VBANK
  jmp VReg

; ClearLayer1 - no text, no canvas.
ClearLayer1:
  jsr CanvasReset
  lda #<V_L1NAME
  ldx #>V_L1NAME
  jsr VAddr
  lda #<1200
  sta T0
  lda #>1200
  sta T1
  lda #0
  jsr FillVram
  lda #<V_L1ATTR
  ldx #>V_L1ATTR
  jsr VAddr
  lda #<1200
  sta T0
  lda #>1200
  sta T1
  lda #0
  jmp FillVram

; --- Text ---

; LineStart / LineChar / LineStr / LineNum build a line in LINEBUF.
LineStart:
  stz LINE_N
  stz LINEBUF
  rts

; LineChar - add character A. Keeps Y.
LineChar:
  ldx LINE_N
  sta LINEBUF,x
  stz LINEBUF+1,x
  inc LINE_N
  rts

; LineStr - add the string X (low), Y (high).
LineStr:
  stx TXT_PTR
  sty TXT_PTR+1
  ldy #0
@loop:
  lda (TXT_PTR),y
  beq @done
  jsr LineChar
  iny
  bra @loop
@done:
  rts

; LineNum - add A as a number with no leading spaces.
LineNum:
  jsr NumToText
  ldy #0
@skip:
  lda DIGITS,y
  cmp #' '
  bne @digits
  iny
  bra @skip
@digits:
  lda DIGITS,y
  beq @done
  jsr LineChar
  iny
  bra @digits
@done:
  rts

; LineShow - LINEBUF on panel row A in TXT_INK.
LineShow:
  ldx #<LINEBUF
  ldy #>LINEBUF
  ; falls through

; Print - the string X (low), Y (high) on panel row A in TXT_INK, padded to
; the panel's width.
Print:
  stx TXT_PTR
  sty TXT_PTR+1
  tax
  lda RowLo,x
  clc
  adc #PANEL_COL
  sta T0
  lda RowHi,x
  adc #0
  sta T1
  ; the characters
  lda T1
  clc
  adc #>V_L1NAME
  tax
  lda T0
  jsr VAddr
  ldy #0
@char:
  lda (TXT_PTR),y
  beq @pad
  sta VC_DATA
  iny
  cpy #PANEL_W
  bne @char
  bra @color
@pad:
  lda #' '
  sta VC_DATA
  iny
  cpy #PANEL_W
  bne @pad
@color:
  lda T1
  clc
  adc #>V_L1ATTR
  tax
  lda T0
  jsr VAddr
  lda TXT_INK                       ; its sub-palette
  clc
  adc #3
  ldy #PANEL_W
@ink:
  sta VC_DATA
  dey
  bne @ink
  rts

; PanelClear - blank panel row A.
PanelClear:
  ldx #<TxtNone
  ldy #>TxtNone
  jmp Print
TxtNone:
  .byte 0

; --- Sprites ---

HideSprites:
  ldx #NUM_SLOTS - 1
@loop:
  lda #HIDE_Y
  sta SPR_Y,x
  stz SPR_X,x
  stz SPR_N,x
  stz SPR_A,x
  dex
  bpl @loop
  rts

HideSprite:
  lda #HIDE_Y
  sta SPR_Y,x
  rts

; PlaceSprite - slot X centered on (HX, HY), pattern A, attribute Y.
PlaceSprite:
  sta SPR_N,x
  tya
  sta SPR_A,x
  lda HX
  sec
  sbc #8
  sta SPR_X,x
  lda HY
  sec
  sbc #8
  sta SPR_Y,x
  rts

UploadSprites:
  lda #<V_SPRATTR
  ldx #>V_SPRATTR
  jsr VAddr
  ldx #0
@slot:
  lda SPR_Y,x
  sta VC_DATA
  lda SPR_X,x
  sta VC_DATA
  lda SPR_N,x
  sta VC_DATA
  lda SPR_A,x
  sta VC_DATA
  inx
  cpx #NUM_SLOTS
  bne @slot
  rts

; --- The canvas ---

; SetTile - all of tile X's pixel bytes to A. Keeps X.
SetTile:
.repeat 16, I
  sta CT_ROWS + I * 256,x
.endrepeat
  rts

; CanvasReset - forget every tile (layer 1 is about to be cleared).
CanvasReset:
  ldx #POOL_TILES - 1
@tile:
  stz TILE_STATE,x
  lda #0
  jsr SetTile
  dex
  cpx #$FF
  bne @tile
  stz ALLOC
  stz POOL_HI
  lda #<CELLMAP
  sta PTR0
  lda #>CELLMAP
  sta PTR0+1
  ldx #5                            ; 1200 bytes fit in 5 pages
  ldy #0
  tya
@page:
  sta (PTR0),y
  iny
  bne @page
  inc PTR0+1
  dex
  bne @page
  rts

; CanvasBegin - start a new drawing. What's on screen stays until
; CanvasFlush, which replaces it in one go, so nothing blinks.
CanvasBegin:
  stz ALLOC
  stz PFILL
  lda #CANVAS_SUB
  sta PATTR
  ldx POOL_HI
@tile:
  lda TILE_STATE,x
  beq @next
  lda #1
  sta TILE_STATE,x
  lda #0
  jsr SetTile
@next:
  dex
  cpx #$FF
  bne @tile
  rts

; CanvasPlot - pixel (PX, PY) in value PINK. A full pool drops it.
CanvasPlot:
  lda PY
  lsr a
  lsr a
  lsr a
  tax
  lda PX
  lsr a
  lsr a
  lsr a
  clc
  adc RowLo,x
  sta CMAP
  lda RowHi,x
  adc #>CELLMAP
  sta CMAP+1
  lda (CMAP)
  bne @have
  ; a new cell: find a free tile
  ldx ALLOC
@find:
  cpx #POOL_TILES
  bcs @full
  lda TILE_STATE,x
  beq @got
  inx
  bra @find
@full:
  stx ALLOC
  rts
@got:
  stx ALLOC
  cpx POOL_HI
  bcc @below
  stx POOL_HI
@below:
  txa
  inc a
  sta (CMAP)
  lda CMAP
  sta TILE_LO,x
  lda CMAP+1
  sta TILE_HI,x
  lda #3
  sta TILE_STATE,x
  bra @fresh
@have:
  dec a
  tax
  lda TILE_STATE,x
  cmp #1
  bne @plot
  lda #2
  sta TILE_STATE,x
@fresh:
  lda PFILL
  beq @plot
  lda #$FF
  jsr SetTile
@plot:
  lda PATTR
  sta TILE_ATTR,x
  phx
  ; which of the tile's 16 bytes: two a row, four pixels each
  lda PY
  and #7
  asl a
  sta PMASK
  lda PX
  and #4
  lsr a
  lsr a
  ora PMASK
  tay
  lda CtLo,y
  sta PTR1
  lda CtHi,y
  sta PTR1+1
  lda PX
  and #3
  tay
  lda PixClear,y
  sta PMASK
  sty T0
  lda PINK
  asl a
  asl a
  ora T0
  tax
  ply
  lda (PTR1),y
  and PMASK
  ora PixBits,x
  sta (PTR1),y
  rts

; CanvasFlush - show the drawing: new tiles in, old ones out.
CanvasFlush:
  stz HI_SET
  ldx POOL_HI
  stz POOL_HI
@tile:
  lda TILE_STATE,x
  bne @used
  jmp @next
@used:
  cmp #1
  bne @drawn
  ; stale: its cell goes blank and the tile is free again
  lda TILE_LO,x
  sta CMAP
  lda TILE_HI,x
  sta CMAP+1
  lda #0
  sta (CMAP)
  stz TILE_STATE,x
  phx
  ldx CMAP+1                        ; its color byte too: it holds the high tile bit
  lda CMAP
  jsr VAddr
  stz VC_DATA
  lda CMAP+1
  sec
  sbc #>CELLMAP - >V_L1NAME
  tax
  lda CMAP
  jsr VAddr
  stz VC_DATA
  plx
  jmp @next
@drawn:
  lda HI_SET                        ; counting down, the first one kept is the top
  bne @topKnown
  inc HI_SET
  stx POOL_HI
@topKnown:
  ; its pixels: pool tile x is at V_POOL + x * 16
  txa
  asl a
  asl a
  asl a
  asl a
  sta T0
  txa
  lsr a
  lsr a
  lsr a
  lsr a
  clc
  adc #>V_POOL
  phx
  tax
  lda T0
  jsr VAddr
  plx
.repeat 16, I
  lda CT_ROWS + I * 256,x
  sta VC_DATA
.endrepeat
  ; its color (CELLMAP sits at the same address as the attribute table)
  lda TILE_HI,x
  phx
  ldy TILE_LO,x
  tax
  tya
  jsr VAddr
  plx
  lda TILE_ATTR,x
  cpx #128                          ; patterns past 255 use the attribute's top bit
  bcc @low
  ora #$80
@low:
  sta VC_DATA
  lda TILE_STATE,x
  cmp #3
  bne @next
  lda #2
  sta TILE_STATE,x
  ; a new cell also needs its name
  lda TILE_HI,x
  sec
  sbc #>CELLMAP - >V_L1NAME
  phx
  ldy TILE_LO,x
  tax
  tya
  jsr VAddr
  plx
  txa
  clc
  adc #128
  sta VC_DATA
@next:
  dex
  cpx #$FF
  beq @done
  jmp @tile
@done:
  rts

CanvasClear:
  jsr CanvasBegin
  jmp CanvasFlush

; ReadGlyph - character A's 8 rows from the font into GLYPH.
ReadGlyph:
  sta T0
  stz T1
  asl T0
  rol T1
  asl T0
  rol T1
  asl T0
  rol T1
  lda T0
  sta VC_REG                        ; a read address: no write bit
  lda T1
  clc
  adc #>V_FONT
  sta VC_REG
  ldx #0
@row:
  lda VC_DATA
  sta GLYPH,x
  inx
  cpx #8
  bne @row
  rts

; BandClear - a solid band across the board for big text.
BandClear:
  ldx #BAND_ROW
@row:
  phx
  lda RowHi,x
  clc
  adc #>V_L1NAME
  pha
  lda RowLo,x
  plx
  pha
  jsr VAddr
  pla
  sta T0
  lda #PAT_SOLID
  ldy #BOARD_CELLS
@name:
  sta VC_DATA
  dey
  bne @name
  txa
  clc
  adc #>V_L1ATTR - >V_L1NAME
  tax
  lda T0
  jsr VAddr
  lda #CANVAS_SUB
  ldy #BOARD_CELLS
@attr:
  sta VC_DATA
  dey
  bne @attr
  plx
  inx
  cpx #BAND_ROW + BAND_ROWS
  bne @row
  rts

; BigText - the string X (low), Y (high), A times normal size, centered on the
; band in TXT_INK.
BigText:
  sta BIG_S
  stx TXT_PTR
  sty TXT_PTR+1
  jsr BandClear
  ldy #0
@len:
  lda (TXT_PTR),y
  beq @counted
  iny
  bra @len
@counted:
  ; width = length * 8 * scale; x = BOARD_X + (220 - width) / 2
  tya
  asl a
  asl a
  asl a
  ldx BIG_S
  jsr Mul8
  lda #220
  sec
  sbc PROD
  lsr a
  clc
  adc #BOARD_X
  sta BIG_X
  ; y centered in the band
  lda BIG_S
  asl a
  asl a
  asl a
  sta T0
  lda #BAND_ROWS * 8
  sec
  sbc T0
  lsr a
  clc
  adc #BAND_ROW * 8
  sta BIG_Y
  jsr CanvasBegin
  lda #1                            ; the letters in the ink, on the dark band
  sta PINK
  sta PFILL
  lda TXT_INK
  clc
  adc #3
  sta PATTR
  stz HD_S                          ; which character
@char:
  ldy HD_S
  lda (TXT_PTR),y
  beq @show
  jsr ReadGlyph
  stz HD_Q                          ; glyph row
@gRow:
  ldx HD_Q
  lda GLYPH,x
  sta HD_DR
  stz RC                            ; glyph column
@gCol:
  asl HD_DR
  bcc @gNext
  jsr BigPixel
@gNext:
  inc RC
  lda RC
  cmp #8
  bne @gCol
  inc HD_Q
  lda HD_Q
  cmp #8
  bne @gRow
  lda BIG_S
  asl a
  asl a
  asl a
  clc
  adc BIG_X
  sta BIG_X
  inc HD_S
  bra @char
@show:
  jmp CanvasFlush

; BigPixel - glyph pixel (RC, HD_Q) as a BIG_S x BIG_S block.
BigPixel:
  lda RC
  ldx BIG_S
  jsr Mul8
  lda PROD
  clc
  adc BIG_X
  sta HD_C1
  lda HD_Q
  ldx BIG_S
  jsr Mul8
  lda PROD
  clc
  adc BIG_Y
  sta PY
  lda BIG_S
  sta HD_R1
@y:
  lda HD_C1
  sta PX
  lda BIG_S
  sta HD_R2
@x:
  jsr CanvasPlot
  inc PX
  dec HD_R2
  bne @x
  inc PY
  dec HD_R1
  bne @y
  rts
