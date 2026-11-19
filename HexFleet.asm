; =============================================================================
;   HexFleet.asm - cartridge entry point
; =============================================================================
;   HexFleet for the AC6502 ACE with a 6502-PICOVDP on BIOS 2.x, as a 128 KB
;   Flash Cart. The fixed 8 KB holds start-up and everything that touches the
;   hardware (vdp, input, sound, plus the maths); bank 0 holds the game and
;   stays selected; banks 1 and 2 hold the art, copied to video memory once.
; =============================================================================

.setcpu "65C02"

.include "6502-VDP.inc"
.include "src/zeropage.inc"
.include "src/assets.inc"
.include "src/vdp.asm"
.include "src/math.asm"
.include "src/hex.asm"
.include "src/input.asm"
.include "src/game.asm"
.include "src/turn.asm"
.include "src/ai.asm"
.include "src/special.asm"
.include "src/scores.asm"
.include "src/link.asm"
.include "src/sound.asm"

.segment "FIXED"

CartReset:
  ldx #$FF
  txs
  stz BANKSHDW                     ; reset selected bank 0
  jsr KernalInit
  jsr KernalVersion
  cmp #2
  bcc @wrongMachine
  lda HW_PRESENT
  and #HW_VID
  bne @ready
@wrongMachine:
  ldx #0
@message:
  lda NeedsMsg,x
  beq @halt
  phx
  jsr Chrout
  plx
  inx
  bra @message
@halt:
  bra @halt

@ready:
  lda #0
  jsr SetIOMode                    ; the keyboard, for Chrin
  cli
  lda #NO_DIR
  sta HELD_DIR
  stz PREV_BTN
  stz SHIP_FACTION                 ; Vanguard against Raider to start
  lda #1
  sta SHIP_FACTION+1
  stz OPP                          ; a normal CPU to start
  lda #$A7
  sta RND
  sta RND+1
  jsr SerialQuiet
  jsr SoundInit
  jsr VideoInit
  jsr LoadScores
  jsr EnterTitle
  jmp MainLoop

NeedsMsg:
  .byte "NEEDS BIOS 2 AND A 6502-PICOVDP", 0

IrqTrampoline:
  jmp (IRQ_PTR)

NmiTrampoline:
  jmp (NMI_PTR)

.segment "VECTORS"
  .word NmiTrampoline
  .word CartReset
  .word IrqTrampoline
