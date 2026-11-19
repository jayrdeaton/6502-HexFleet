; =============================================================================
;   sound.asm - sound effects and music on the SID
; =============================================================================
;   The HexFleet app's sounds and music, rebuilt for the SID's three voices
;   (tools/build-sound.mjs holds them). Music plays on all three. An effect takes
;   over voice 3, or voice 2 when it needs a second voice or 3 is busy with
;   something that matters more, and the music picks the voice up again at its
;   next note.
;
;   A timer interrupt runs SoundTick 60 times a second from bank 3, so the sound
;   keeps time however busy the game is. The game only leaves requests in a queue.
;   This fixed-bank half holds those calls and the interrupt handler.
; =============================================================================

.segment "CART"

TIMER_FRAME   = 16600              ; a 60th of a second, less the time to restart it
REQ_LASER_OFF = $F0
REQ_ALL_OFF   = $F1
SOUND_BANK    = 3

; SoundInit - silence, then start the timer and take over the interrupt.
SoundInit:
  ldx #S_VARS_END - S_REG - 1
@clear:
  stz S_REG,x
  dex
  bpl @clear
  stz SND_LASER
  lda #15
  sta S_MASTER
  lda #1
  sta MUS_ON
  lda IRQ_PTR
  sta OLD_IRQ
  lda IRQ_PTR+1
  sta OLD_IRQ+1
  sei
  lda #<SysIrq
  sta IRQ_PTR
  lda #>SysIrq
  sta IRQ_PTR+1
  lda HW_PRESENT
  and #HW_SID
  beq @noSid
  ldx #$18
@sid:
  stz SID_V1_FREQ_LO,x
  dex
  bpl @sid
  lda HW_PRESENT
  and #HW_GPIO
  beq @noSid
  lda #1
  sta S_ON
  lda GPIO_ACR
  and #%11011111                   ; timer 2 counts clock cycles
  sta GPIO_ACR
  lda #GPIO_IER_SET | GPIO_INT_T2
  sta GPIO_IER
  lda #<TIMER_FRAME
  sta GPIO_T2CL
  lda #>TIMER_FRAME
  sta GPIO_T2CH
@noSid:
  cli
  rts

; SysIrq - the machine's interrupt handler from now on: serial bytes while linked,
; the keyboard as the Kernal handles it, and the sound timer. The sound runs with
; interrupts back on, so a long tick can't make the serial port lose a byte.
SysIrq:
  pha
  phx
  phy
  tsx
  lda $104,x                       ; the saved flags: a BRK is the Kernal's
  and #$10
  bne @brk
  lda LINK_ON
  beq @keys
  lda SC_STATUS
  and #SC_STATUS_RDRF
  beq @keys
  lda SC_DATA
  ldx RX_HEAD
  sta RX_BUF,x
  inc RX_HEAD
@keys:
  lda HW_PRESENT
  and #HW_GPIO
  beq @exit
  lda GPIO_IFR
  and #GPIO_INT_CB1
  beq @ps2
  lda GPIO_PORTB
  jsr WriteBuffer
  bra @timer
@ps2:
  lda GPIO_IFR
  and #GPIO_INT_CA1
  beq @timer
  lda GPIO_PORTA
  jsr WriteBuffer
@timer:
  lda GPIO_IFR
  and #GPIO_INT_T2
  beq @exit
  lda #<TIMER_FRAME
  sta GPIO_T2CL
  lda #>TIMER_FRAME
  sta GPIO_T2CH                    ; also clears the flag
  lda S_BUSY
  bne @exit                        ; the last tick is still running
  inc S_BUSY
  lda BANKSHDW
  pha
  lda #SOUND_BANK
  sta BANK
  cli
  jsr SoundTick
  sei
  pla
  sta BANK
  stz S_BUSY
@exit:
  ply
  plx
  pla
  rti
@brk:
  ply
  plx
  pla
  jmp (OLD_IRQ)

; --- What the game calls. These keep X and Y. ---

; SoundRequest - leave request A for the next tick.
SoundRequest:
  phx
  ldx S_ON
  beq @done
  ldx S_QH
  sta S_Q,x
  inx
  cpx #8
  bcc @stored
  ldx #0
@stored:
  stx S_QH
@done:
  plx
  rts

.macro SOUND name, effect
name:
  lda #effect
  jmp SoundRequest
.endmacro

SOUND SndPick, SFX_PRESS
SOUND SndBack, SFX_BACK
SOUND SndCommit, SFX_COMMIT
SOUND SndError, SFX_ERROR
SOUND SndHit, SFX_HIT
SOUND SndTorpHit, SFX_TORPHIT
SOUND SndBoom, SFX_BOOM
SOUND SndBlast, SFX_BLAST
SOUND SndTorpedo, SFX_TORPEDO
SOUND SndThrust, SFX_THRUST
SOUND SndWarp, SFX_JUMP
SOUND SndCloak, SFX_CLOAK
SOUND SndMine, SFX_MINE

SndLaserOn:
  lda SND_LASER
  bne @done
  inc SND_LASER
  lda #SFX_LASER
  jmp SoundRequest
@done:
  rts

SndLaserOff:
  lda SND_LASER
  beq @done
  stz SND_LASER
  lda #REQ_LASER_OFF
  jmp SoundRequest
@done:
  rts

SoundOff:
  stz SND_LASER
  lda #REQ_ALL_OFF
  jmp SoundRequest

; PlayMusic - tune A from the top, unless it's already playing.
PlayMusic:
  sta MUS_WANT
  rts

ToggleMusic:
  lda MUS_ON
  eor #1
  sta MUS_ON
  rts

; =============================================================================
;   The driver, in bank 3. Everything here runs in the interrupt, so it keeps to
;   its own memory and calls nothing outside this bank.
; =============================================================================

.segment "BANK03"

.include "sounddata.inc"

VoiceBase:
  .byte 0, 7, 14

SoundTick:
  inc S_TICKS
  bne @counted
  inc S_TICKS+1
@counted:
  jsr TakeRequests
  jsr ChooseTune
  ldx #2
@track:
  jsr TrackTick
  dex
  bpl @track
  ldx #2
@effect:
  jsr EffectTick
  dex
  bne @effect
  jsr FilterTick
  ; --- everything to the chip at once ---
  ldx #2
@retrigger:
  lda S_PEND,x
  beq @noRetrigger
  stz S_PEND,x
  inc S_RTG,x
  ldy VoiceBase,x
  lda S_REG+4,y
  and #$FE
  sta SID_V1_FREQ_LO+4,y           ; let go first, so the note starts again
@noRetrigger:
  dex
  bpl @retrigger
  ldx #$18
@copy:
  lda S_REG,x
  sta SID_V1_FREQ_LO,x
  dex
  bpl @copy
  rts

TakeRequests:
  ldx S_QT
  cpx S_QH
  beq @done
  lda S_Q,x
  inx
  cpx #8
  bcc @stored
  ldx #0
@stored:
  stx S_QT
  cmp #REQ_LASER_OFF
  beq @laserOff
  cmp #REQ_ALL_OFF
  beq @allOff
  jsr EffectStart
  bra TakeRequests
@laserOff:
  ldx #1
  lda SF_ID,x
  cmp #SFX_LASER
  bne TakeRequests
  jsr EffectEnd
  bra TakeRequests
@allOff:
  ldx #1
  jsr EffectEnd
  ldx #2
  jsr EffectEnd
  bra TakeRequests
@done:
  rts

; --- Effects ---

; CanTake - carry set if an effect of priority S_A may have voice X.
CanTake:
  lda SF_ID,x
  beq @yes
  lda S_A
  cmp SF_P,x                       ; carry set if it matters as much or more
  rts
@yes:
  sec
  rts

; EffectStart - effect A on the voice it prefers, or its other choice. Keeps X.
EffectStart:
  phx
  tay
  lda FxPrio,y
  sta S_A
  ldx FxVoice,y
  jsr CanTake
  bcs @take
  lda FxOther,y
  beq @done
  txa
  eor #3                           ; 1 and 2 swap
  tax
  jsr CanTake
  bcc @done
@take:
  tya
  sta SF_ID,x
  lda S_A
  sta SF_P,x
  lda FxLo,y
  sta SF_PL,x
  lda FxHi,y
  sta SF_PH,x
  stz SF_LEFT,x
  lda FxPair,y
  beq @done
  jsr EffectStart
@done:
  plx
  rts

; EffectEnd - voice X lets go and goes back to the music.
EffectEnd:
  lda SF_ID,x
  beq @done
  stz SF_ID,x
  stz SF_FIL,x
  ldy VoiceBase,x
  lda S_REG+4,y
  and #$FE
  sta S_REG+4,y
@done:
  rts

; EffectTick - voice X's effect, one frame on.
EffectTick:
  lda SF_ID,x
  beq @done
  lda SF_LEFT,x
  bne @run
  jsr NextStep
  lda SF_ID,x
  beq @done
@run:
  dec SF_LEFT,x
  ldy VoiceBase,x
  lda SF_FLG,x
  and #$20
  beq @noChop
  lda S_REG+4,y                    ; chopped: the gate flips every frame
  eor #1
  sta S_REG+4,y
@noChop:
  lda SF_FLG,x
  and #$0F
  beq @write
  jsr SlidePitch
@write:
  ldy VoiceBase,x
  lda SF_FL,x
  sta S_REG,y
  lda SF_FH,x
  sta S_REG+1,y
@done:
  rts

; NextStep - load voice X's next step, or end the effect.
NextStep:
  lda SF_PL,x
  sta S_P
  lda SF_PH,x
  sta S_P+1
  lda (S_P)
  bne @step
  jmp EffectEnd
@step:
  cmp #$FF
  bne @load
  ; go back some steps
  ldy #1
  lda (S_P),y
  asl a
  asl a
  sta S_B
  asl a
  clc
  adc S_B                          ; 12 bytes a step
  sta S_B
  lda S_P
  sec
  sbc S_B
  sta S_P
  bcs @back
  dec S_P+1
@back:
  lda (S_P)
@load:
  sta SF_LEFT,x
  phx
  lda VoiceBase,x
  tax
  ldy #1
  lda (S_P),y
  sta S_REG+4,x
  iny
  lda (S_P),y
  sta S_REG+5,x
  iny
  lda (S_P),y
  sta S_REG+6,x
  ldy #9
  lda (S_P),y
  sta S_REG+3,x
  stz S_REG+2,x
  plx
  ldy #8
  lda (S_P),y
  sta SF_FLG,x
  bmi @kept                        ; carries on from the last pitch
  ldy #4
  lda (S_P),y
  sta SF_FL,x
  iny
  lda (S_P),y
  sta SF_FH,x
  iny
  lda (S_P),y
  sta SF_TL,x
  iny
  lda (S_P),y
  sta SF_TH,x
@kept:
  ldy #10
  lda (S_P),y
  beq @noFilter
  sta S_FXC
  iny
  lda (S_P),y
  sta S_FXK
  lda #1
@noFilter:
  sta SF_FIL,x
  lda SF_FLG,x
  and #$10
  beq @noRetrigger
  lda #1
  sta S_PEND,x
@noRetrigger:
  lda S_P
  clc
  adc #12
  sta SF_PL,x
  lda S_P+1
  adc #0
  sta SF_PH,x
  rts

; SlidePitch - voice X's pitch toward its target.
SlidePitch:
  lda SF_FLG,x
  and #$40
  bne @grow
  ; a share of the distance left
  lda SF_TL,x
  sec
  sbc SF_FL,x
  sta S_B
  lda SF_TH,x
  sbc SF_FH,x
  sta S_C
  jsr ShiftStep
  lda S_B
  ora S_C
  beq @arrive
  lda SF_FL,x
  clc
  adc S_B
  sta SF_FL,x
  lda SF_FH,x
  adc S_C
  sta SF_FH,x
  rts
@arrive:
  lda SF_TL,x
  sta SF_FL,x
  lda SF_TH,x
  sta SF_FH,x
  rts
@grow:
  lda SF_FL,x
  sta S_B
  lda SF_FH,x
  sta S_C
  jsr ShiftStep
  lda SF_FL,x
  clc
  adc S_B
  sta SF_FL,x
  lda SF_FH,x
  adc S_C
  sta SF_FH,x
  bcs @arrive
  cmp SF_TH,x
  bcs @arrive
  rts

; ShiftStep - S_C:S_B, signed, shifted right by voice X's slide amount.
ShiftStep:
  lda SF_FLG,x
  and #$0F
  tay
@shift:
  lda S_C
  cmp #$80
  ror S_C
  ror S_B
  dey
  bne @shift
  rts

; --- Music ---

; ChooseTune - start the tune asked for, or stop if music is off.
ChooseTune:
  lda MUS_ON
  beq @wanted
  lda MUS_WANT
@wanted:
  cmp MUS_ID
  beq @done
  sta MUS_ID
  stz M_LFO
  stz M_LFO+1
  ldx #2
@track:
  stz M_LEFT,x
  stz M_GATE,x
  stz M_FILT,x
  stz M_RATE,x
  lda SF_ID,x
  bne @busy
  ldy VoiceBase,x
  lda S_REG+4,y
  and #$FE
  sta S_REG+4,y
@busy:
  lda MUS_ID
  beq @next
  asl a
  adc MUS_ID                       ; 3 tracks a tune
  sec
  sbc #3
  stx S_A
  clc
  adc S_A
  tay
  iny
  lda TuneTrackLo,y
  sta M_PL,x
  sta M_SL,x
  lda TuneTrackHi,y
  sta M_PH,x
  sta M_SH,x
@next:
  dex
  bpl @track
@done:
  rts

; TrackTick - track X, one frame on.
TrackTick:
  lda MUS_ID
  beq @done
  lda M_LEFT,x
  bne @run
  jsr NextEvent
@run:
  dec M_LEFT,x
  lda SF_ID,x
  bne @done                        ; an effect has this voice
  ldy VoiceBase,x
  lda M_GATE,x
  beq @drift
  cmp M_LEFT,x
  bne @drift
  lda S_REG+4,y                    ; time for this note to let go
  and #$FE
  sta S_REG+4,y
@drift:
  lda M_RATE,x
  beq @done
  clc
  adc S_REG+2,y
  sta S_REG+2,y
  bcc @done
  lda S_REG+3,y
  inc a
  and #$0F
  bne @width
  lda #2                           ; never so narrow that it vanishes
@width:
  sta S_REG+3,y
@done:
  rts

NextEvent:
  lda M_PL,x
  sta S_P
  lda M_PH,x
  sta S_P+1
  lda (S_P)
  bne @event
  lda M_SL,x                       ; the end: round again
  sta S_P
  lda M_SH,x
  sta S_P+1
  lda (S_P)
@event:
  sta M_LEFT,x
  ldy #1
  lda (S_P),y
  sta S_B
  iny
  lda (S_P),y
  sta S_C
  lda S_P
  clc
  adc #3
  sta M_PL,x
  lda S_P+1
  adc #0
  sta M_PH,x
  lda S_B
  beq @rest
  cmp #KICK_NOTE
  bne StartNote
  lda #SFX_THUMP
  jmp EffectStart
@rest:
  stz M_GATE,x
  stz M_RATE,x
  rts

; StartNote - note S_B with instrument S_C on track X.
StartNote:
  lda S_C
  asl a
  asl a
  asl a
  tay
  lda Instruments+4,y
  sta M_RATE,x
  lda M_LEFT,x                     ; it lets go after being held this long
  sec
  sbc Instruments+5,y
  bcs @gate
  lda #0
@gate:
  sta M_GATE,x
  lda Instruments+6,y
  sta M_FILT,x
  lda Instruments+7,y
  beq @noKick
  sta F_ENV
@noKick:
  lda SF_ID,x
  bne @done                        ; the voice is busy: this note goes unheard
  phx
  sty S_A
  lda VoiceBase,x
  tax
  ldy S_B
  lda NoteLo,y
  sta S_REG,x
  lda NoteHi,y
  sta S_REG+1,x
  ldy S_A
  lda Instruments,y
  sta S_REG+4,x
  lda Instruments+1,y
  sta S_REG+5,x
  lda Instruments+2,y
  sta S_REG+6,x
  lda Instruments+3,y
  sta S_REG+3,x
  stz S_REG+2,x
  plx
  lda #1
  sta S_PEND,x
@done:
  rts

; FilterTick - the filter breathes, opens on each bass note and settles back.
FilterTick:
  lda MUS_ID
  asl a
  adc MUS_ID
  tay                              ; 3 bytes a tune
  lda M_LFO
  clc
  adc TuneFilter+1,y
  sta M_LFO
  bcc @phase
  inc M_LFO+1
@phase:
  lda M_LFO+1
  asl a
  bcc @rising
  eor #$FF
@rising:
  lsr a
  lsr a
  lsr a
  clc
  adc TuneFilter,y
  sta S_B
  lda F_ENV
  beq @open
  lsr a
  lsr a
  lsr a
  bne @fall
  lda #1
@fall:
  sta S_C
  lda F_ENV
  pha
  sec
  sbc S_C
  sta F_ENV
  pla
@open:
  clc
  adc S_B
  sta S_REG+$16
  stz S_REG+$15
  ; which voices go through it
  stz S_C
  stz S_B
  ldx #2
@voice:
  lda SF_ID,x
  beq @music
  lda SF_FIL,x
  beq @direct
  inc S_B                          ; an effect is using the filter
  bra @route
@music:
  lda M_FILT,x
  beq @direct
@route:
  lda VoiceBit,x
  ora S_C
  sta S_C
@direct:
  dex
  bpl @voice
  lda S_B
  beq @setRouting
  ; an effect's own cutoff, closing as it goes, wins
  lda S_FXC
  sta S_REG+$16
  ldx S_FXK
  beq @setRouting
@close:
  lsr a
  dex
  bne @close
  inc a
  eor #$FF
  sec
  adc S_FXC
  cmp #20
  bcs @closed
  lda #20
@closed:
  sta S_FXC
@setRouting:
  lda TuneFilter+2,y
  asl a
  asl a
  asl a
  asl a
  ora S_C
  sta S_REG+$17
  lda S_MASTER
  ora #SID_FILT_LP
  sta S_REG+$18
  rts

VoiceBit:
  .byte 1, 2, 4
