; =============================================================================
;   hex.asm - the board's hexes: centers, row lengths, distance, headings
; =============================================================================
;   The board is the app's: 15 rows of pointy hexes. A hex is (C, R): row R
;   0..14 from the top, column C from the left. Even rows hold 10 hexes and
;   sit half a hex to the right; odd rows hold 11. Hexes are 20 pixels wide
;   and rows 15 pixels apart.
; =============================================================================

.segment "CART"

; floor((R - 7) / 2) for each row: turns (C, R) into the engine's axial q
FloorHalf:
  .byte $FC, $FD, $FD, $FE, $FE, $FF, $FF, 0, 0, 1, 1, 2, 2, 3, 3

; HexCenter - X = column, Y = row: the center pixel in HX, HY. Keeps X, Y.
HexCenter:
  sty HC_T
  tya
  asl a
  asl a
  asl a
  asl a                            ; 16R
  sec
  sbc HC_T                         ; 15R
  clc
  adc #BOARD_Y + 10
  sta HY
  txa
  asl a
  asl a                            ; 4C
  sta HC_T
  asl a
  asl a                            ; 16C
  clc
  adc HC_T                         ; 20C
  adc #BOARD_X + 10
  sta HX
  tya
  and #1
  bne @done
  lda HX                           ; even rows sit half a hex right
  clc
  adc #10
  sta HX
@done:
  rts

; RowLen - A = row: A = hexes in it.
RowLen:
  and #1
  beq @even
  lda #11
  rts
@even:
  lda #10
  rts

; HexDist - hexes between (HD_C1, HD_R1) and (HD_C2, HD_R2), in A.
; Clobbers X.
HexDist:
  ldx HD_R1
  lda HD_C1
  sec
  sbc FloorHalf,x
  sta HD_Q                         ; q1
  ldx HD_R2
  lda HD_C2
  sec
  sbc FloorHalf,x                  ; q2
  sta HD_S
  lda HD_Q
  sec
  sbc HD_S
  sta HD_Q                         ; dq
  lda HD_R1
  sec
  sbc HD_R2
  sta HD_DR                        ; dr
  clc
  adc HD_Q
  jsr Abs8                         ; |dq + dr|
  sta HD_S
  lda HD_Q
  jsr Abs8
  clc
  adc HD_S
  sta HD_S
  lda HD_DR
  jsr Abs8
  clc
  adc HD_S
  lsr a                            ; half of |dq| + |dr| + |dq + dr|
  rts

; HeadingOf - heading 0..11 (0 up, then every 30 degrees clockwise) of the
; vector HDX, HDY (signed 16-bit pixels), in A; $FF if it's zero.
HeadingOf:
  lda HDX
  sta SD_DX
  lda HDX+1
  sta SD_DX+1
  lda HDY
  sta SD_DY
  lda HDY+1
  sta SD_DY+1
  jsr ScaleDir
  bne @moving
  lda #$FF
  rts
@moving:
  lda DIRX
  jsr Abs8
  sta HG_AX
  lda DIRY
  jsr Abs8
  sta HG_AY
  ; how far from vertical: 0 (within 15 degrees) to 3 (horizontal)
  lda HG_AX
  asl a
  asl a
  cmp HG_AY
  bcc @s0
  beq @s0
  lda HG_AX
  cmp HG_AY
  bcc @s1
  beq @s1
  lda HG_AY
  asl a
  asl a
  cmp HG_AX
  bcs @s2
  lda #3
  bra @sector
@s0:
  lda #0
  bra @sector
@s1:
  lda #1
  bra @sector
@s2:
  lda #2
@sector:
  sta HG_S
  ; which quarter
  lda DIRX
  bmi @left
  lda DIRY
  bmi @upRight
  lda #6                           ; down and right: 6 - s
  sec
  sbc HG_S
  rts
@upRight:
  lda HG_S                         ; up and right: s
  rts
@left:
  lda DIRY
  bmi @upLeft
  lda #6                           ; down and left: 6 + s
  clc
  adc HG_S
  rts
@upLeft:
  lda #12                          ; up and left: 12 - s, 0 for straight up
  sec
  sbc HG_S
  cmp #12
  bne @done
  lda #0
@done:
  rts
