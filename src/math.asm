; =============================================================================
;   math.asm - multiply, divide, square root, absolute value
; =============================================================================

.segment "CART"

; Mul8 - A * X, unsigned, into PROD (16-bit). Clobbers A, X.
Mul8:
  sta MUL1
  stx MUL2
  lda #0
  ldx #8
  lsr MUL2
@loop:
  bcc @noAdd
  clc
  adc MUL1
@noAdd:
  ror a
  ror PROD
  lsr MUL2
  dex
  bne @loop
  sta PROD+1
  rts

; SMul - MA (signed byte) * MB (signed 16-bit, |MB| < 256) into PROD,
; signed. Clobbers A, X.
SMul:
  stz MSIGN
  lda MB+1
  bpl @bPos
  lda MB                           ; |MB| = -MB, which fits in a byte
  eor #$FF
  clc
  adc #1
  sta MAGB
  inc MSIGN
  bra @a
@bPos:
  lda MB
  sta MAGB
@a:
  lda MA
  bpl @aPos
  eor #$FF
  clc
  adc #1
  pha
  lda MSIGN
  eor #1
  sta MSIGN
  pla
@aPos:
  ldx MAGB
  jsr Mul8
  lda MSIGN
  beq @done
  jmp NegProd
@done:
  rts

; NegProd - PROD = -PROD.
NegProd:
  lda PROD
  eor #$FF
  clc
  adc #1
  sta PROD
  lda PROD+1
  eor #$FF
  adc #0
  sta PROD+1
  rts

; Div16 - DIVIDEND (16-bit) / DIVISOR (8-bit, not 0) into QUOT (16-bit) and
; REM. Clobbers A, X, DIVIDEND.
Div16:
  lda #0
  ldx #16
@loop:
  asl DIVIDEND
  rol DIVIDEND+1
  rol a
  bcs @sub                         ; remainder passed 255: it's over DIVISOR
  cmp DIVISOR
  bcc @skip
@sub:
  sbc DIVISOR                      ; carry is set either way
  inc DIVIDEND                     ; this quotient bit is 1
@skip:
  dex
  bne @loop
  sta REM
  lda DIVIDEND
  sta QUOT
  lda DIVIDEND+1
  sta QUOT+1
  rts

; Isqrt - square root of SQRT_IN (16-bit, under 16384), rounded down, in A.
; Clobbers X.
Isqrt:
  stz SQ_R
  lda #$80
  sta SQ_BIT
@loop:
  lda SQ_R
  ora SQ_BIT
  sta SQ_T
  tax
  jsr Mul8
  lda PROD+1                       ; keep the bit if SQ_T squared <= SQRT_IN
  cmp SQRT_IN+1
  bcc @take
  bne @skip
  lda PROD
  cmp SQRT_IN
  beq @take
  bcs @skip
@take:
  lda SQ_T
  sta SQ_R
@skip:
  lsr SQ_BIT
  bne @loop
  lda SQ_R
  rts

; Abs8 - A = |A| for a signed byte.
Abs8:
  bpl @done
  eor #$FF
  clc
  adc #1
@done:
  rts

; ScaleDir - shrink the vector SD_DX, SD_DY (signed 16-bit, each under 256
; in size) until both fit under 64, keeping its direction, into DIRX, DIRY.
; Z is set if the vector is zero. Clobbers A, X.
ScaleDir:
  stz SD_NX
  stz SD_NY
  lda SD_DX+1
  bpl @xPos
  lda SD_DX
  eor #$FF
  clc
  adc #1
  inc SD_NX
  bra @xDone
@xPos:
  lda SD_DX
@xDone:
  sta SD_AX
  lda SD_DY+1
  bpl @yPos
  lda SD_DY
  eor #$FF
  clc
  adc #1
  inc SD_NY
  bra @yDone
@yPos:
  lda SD_DY
@yDone:
  sta SD_AY
@shrink:
  lda SD_AX
  ora SD_AY
  and #$C0
  beq @fits
  lsr SD_AX
  lsr SD_AY
  bra @shrink
@fits:
  lda SD_AX
  ldx SD_NX
  beq @setX
  eor #$FF
  clc
  adc #1
@setX:
  sta DIRX
  lda SD_AY
  ldx SD_NY
  beq @setY
  eor #$FF
  clc
  adc #1
@setY:
  sta DIRY
  lda SD_AX
  ora SD_AY
  rts

; DirLength - LEN = length of (DIRX, DIRY). Clobbers A, X.
DirLength:
  lda DIRX
  jsr Abs8
  tax
  jsr Mul8
  lda PROD
  sta SQRT_IN
  lda PROD+1
  sta SQRT_IN+1
  lda DIRY
  jsr Abs8
  tax
  jsr Mul8
  lda PROD
  clc
  adc SQRT_IN
  sta SQRT_IN
  lda PROD+1
  adc SQRT_IN+1
  sta SQRT_IN+1
  jsr Isqrt
  sta LEN
  rts

; NumToText - A (0..255) as three characters, leading spaces, in DIGITS.
NumToText:
  sta NT_V
  ldx #' '
  stx DIGITS
  stx DIGITS+1
  stz DIGITS+3
  ldx #0                           ; hundreds
@hundreds:
  cmp #100
  bcc @tens
  sbc #100
  inx
  bra @hundreds
@tens:
  cpx #0
  beq @noHundreds
  pha
  txa
  ora #'0'
  sta DIGITS
  pla
@noHundreds:
  ldx #0
@tensLoop:
  cmp #10
  bcc @ones
  sbc #10
  inx
  bra @tensLoop
@ones:
  ora #'0'
  sta DIGITS+2
  cpx #0
  bne @setTens
  lda DIGITS                       ; a zero tens digit shows only after hundreds
  cmp #' '
  beq @done
@setTens:
  txa
  ora #'0'
  sta DIGITS+1
@done:
  rts
