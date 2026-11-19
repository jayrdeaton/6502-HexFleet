; =============================================================================
;   input.asm - joysticks and keyboard as one set of controls
; =============================================================================
;   Only one person plans at a time, so either joystick and either key
;   cluster drive the same cursor:
;     move:  stick, W A S D, or the arrow keys
;     pick:  fire (A), Space or Enter
;     swap:  B, or X on the keyboard (Laser, Torpedo, the special)
;   A held stick moves once, then repeats.
; =============================================================================

.include "../../6502-Lib/include/input.inc"
.include "../../6502-Lib/core/input.asm"

.segment "CART"

REPEAT_FIRST = 15                 ; frames before a held stick repeats
REPEAT_NEXT  = 5                  ; then every this many

; ReadInput - this frame's EV_DIR, EV_FIRE and EV_SWAP.
ReadInput:
  stz EV_FIRE
  stz EV_SWAP
  lda #NO_DIR
  sta EV_DIR
  jsr PollJoy1
  jsr PollJoy2
  lda JOY_STATE
  and JOY_STATE2                   ; active low: pressed on either stick
  eor #$FF
  sta T0                           ; active high
  ; buttons, on the press
  lda PREV_BTN
  eor #$FF
  and T0
  sta T1
  and #JOY_A
  beq @noFire
  inc EV_FIRE
@noFire:
  lda T1
  and #JOY_B
  beq @noSwap
  inc EV_SWAP
@noSwap:
  lda T0
  and #(JOY_A | JOY_B)
  sta PREV_BTN
  ; the stick's direction
  ldx #NO_DIR
  lda T0
  and #JOY_UP
  beq @notUp
  ldx #DIR_UP
@notUp:
  lda T0
  and #JOY_DOWN
  beq @notDown
  ldx #DIR_DOWN
@notDown:
  lda T0
  and #JOY_LEFT
  beq @notLeft
  ldx #DIR_LEFT
@notLeft:
  lda T0
  and #JOY_RIGHT
  beq @notRight
  ldx #DIR_RIGHT
@notRight:
  cpx HELD_DIR
  beq @held
  stx HELD_DIR                     ; a new direction: move now
  cpx #NO_DIR
  beq @keys
  stx EV_DIR
  lda #REPEAT_FIRST
  sta REPEAT_T
  bra @keys
@held:
  cpx #NO_DIR
  beq @keys
  dec REPEAT_T
  bne @keys
  stx EV_DIR
  lda #REPEAT_NEXT
  sta REPEAT_T
@keys:
  jsr BufferSize                   ; straight from the buffer: Chrin would echo
  cmp #0                           ; the key onto the Kernal's text screen
  beq @done
  jsr ReadBuffer
  ldx #DIR_UP
  cmp #'W'
  beq @keyDir
  cmp #KEY_UP_ARROW
  beq @keyDir
  ldx #DIR_DOWN
  cmp #'S'
  beq @keyDir
  cmp #KEY_DOWN_ARROW
  beq @keyDir
  ldx #DIR_LEFT
  cmp #'A'
  beq @keyDir
  cmp #KEY_LEFT_ARROW
  beq @keyDir
  ldx #DIR_RIGHT
  cmp #'D'
  beq @keyDir
  cmp #KEY_RIGHT_ARROW
  beq @keyDir
  cmp #' '
  beq @keyFire
  cmp #$0D
  beq @keyFire
  cmp #'X'
  beq @keySwap
  cmp #'B'
  beq @keySwap
  bra @keys
@keyDir:
  stx EV_DIR
  bra @keys
@keyFire:
  lda #1
  sta EV_FIRE
  bra @keys
@keySwap:
  lda #1
  sta EV_SWAP
  bra @keys
@done:
  rts
