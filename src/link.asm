; =============================================================================
;   link.asm - two machines, one battle, over the serial port
; =============================================================================
;   Each player plans on their own machine. Turns need no dice, so once both
;   machines hold both plans they each play the same turn and get the same
;   result, and only the plans cross the cable.
;
;   Everything is sent as 11-byte frames: $A5, type, turn, 6 bytes, a 2-byte check.
;   A frame that arrives damaged is dropped, and whatever it carried is sent
;   again until the other machine answers, so a noisy cable only costs time.
;     HELLO  finds the other machine: who it is, its ship, how far along it is.
;     PLAN   a turn's orders, and a checksum of the battle so far: two machines
;            that disagree stop and say so rather than play on.
;     ACK    that turn's plan arrived.
;   A machine plays the turn once it has the other's plan and knows its own got
;   through. Received bytes go into a ring from the interrupt (SysIrq, in
;   sound.asm), so nothing is lost while a turn is playing.
; =============================================================================

.segment "CART"

; SerialQuiet - no serial interrupts: another machine calling must not reach the
; keyboard buffer while this one isn't linked.
SerialQuiet:
  lda HW_PRESENT
  and #HW_SC
  beq @done
  lda SC_CMD
  ora #SC_CMD_RXIRQ_OFF
  sta SC_CMD
@done:
  rts

.segment "BANK00"

FRAME_SYNC    = $A5
FRAME_SIZE    = 11
FR_HELLO      = 1
FR_PLAN       = 2
FR_ACK        = 3
LINK_VERSION  = 1
LINK_RESEND   = 20                 ; frames between tries
POLL_BYTES    = 40                 ; bytes handled a frame at most
BAD_SYNC      = 1                  ; LINK_BAD
BAD_VERSION   = 2

TxtLink:       .asciiz "LINK"
TxtLinked:     .asciiz " LINKED"
TxtLinking:    .asciiz "LINKING"
TxtWaitOther:  .asciiz "WAITING FOR"
TxtOtherCart:  .asciiz "OTHER CART"
TxtQuit:       .asciiz "B/X: QUIT"
TxtNoSerial:   .asciiz "NO SERIAL"
TxtOutOfSync:  .asciiz "OUT OF SYNC"
TxtWrongCart:  .asciiz "OTHER BUILD"
TxtOrders:     .asciiz "YOUR ORDERS"
TxtOtherReady: .asciiz "OTHER READY"
TxtYouLose:    .asciiz "YOU LOSE"

; IsLink - Z set in a linked game.
IsLink:
  lda MODE
  cmp #M_LINK
  rts

; --- Starting and stopping ---

LinkOn:
  sei
  stz RX_HEAD
  stz RX_TAIL
  jsr InitSC
  cli
  stz PARSE_N
  stz LINK_UP
  stz LINK_BAD
  stz HAVE_HELLO
  stz PEER_HAS
  stz HAVE_PLAN
  stz PEER_ACK
  lda #1
  sta LINK_ON
  lda CFG_FAC
  sta MY_FACTION
  sta TITLE_F
  lda CFG_FAC+1
  sta TITLE_F+1
  rts

; LinkOff - back to a machine on its own, with the title's ships as they were.
LinkOff:
  lda LINK_ON
  beq @done
  stz LINK_ON
  jsr SerialQuiet
  lda TITLE_F
  sta CFG_FAC
  lda TITLE_F+1
  sta CFG_FAC+1
@done:
  rts

NewNonce:
  jsr Rnd
  sta MY_NONCE
  jsr Rnd
  sta MY_NONCE+1
  rts

EnterLink:
  lda HW_PRESENT
  and #HW_SC
  bne @card
  ldx #<TxtNoSerial
  ldy #>TxtNoSerial
  jmp LinkFail
@card:
  jsr LinkOn
  jsr NewNonce
  lda #ST_LINK
  sta STATE
  lda #1
  sta LINK_T
  jsr ClearMessages
  lda #INK_WHITE
  sta TXT_INK
  lda #ROW_MSG1
  ldx #<TxtLinking
  ldy #>TxtLinking
  jsr Print
  lda #INK_GRAY
  sta TXT_INK
  lda #ROW_MSG2
  ldx #<TxtWaitOther
  ldy #>TxtWaitOther
  jsr Print
  lda #ROW_MSG3
  ldx #<TxtOtherCart
  ldy #>TxtOtherCart
  jsr Print
  ; falls through

PrintQuit:
  lda #INK_GRAY
  sta TXT_INK
  lda #ROW_MSG6
  ldx #<TxtQuit
  ldy #>TxtQuit
  jmp Print

; LinkFail - the message X (low), Y (high), and back to the menu from there.
LinkFail:
  phx
  phy
  lda #ST_OVER
  sta STATE
  jsr SoundOff
  jsr HideMarkers
  jsr UploadSprites
  jsr CanvasClear
  jsr ClearMessages
  lda #INK_RED
  sta TXT_INK
  ply
  plx
  lda #ROW_MSG2
  jsr Print
  lda #INK_WHITE
  sta TXT_INK
  lda #ROW_MSG3
  ldx #<TxtFireMenu
  ldy #>TxtFireMenu
  jmp Print

LinkBroken:
  lda LINK_BAD
  cmp #BAD_VERSION
  beq @version
  ldx #<TxtOutOfSync
  ldy #>TxtOutOfSync
  jmp LinkFail
@version:
  ldx #<TxtWrongCart
  ldy #>TxtWrongCart
  jmp LinkFail

; --- Each frame ---

LinkFrame:
  jsr LinkPoll
  lda LINK_BAD
  bne LinkBroken
  lda HAVE_HELLO
  beq @waiting
  lda PEER_HAS
  bne LinkGo
@waiting:
  lda EV_SWAP
  beq @timer
  jmp EnterTitle
@timer:
  dec LINK_T
  bne @done
  lda #LINK_RESEND
  sta LINK_T
  jmp SendHello
@done:
  rts

; LinkGo - both machines know each other: the lower number takes the first seat.
LinkGo:
  lda #1
  sta LINK_UP
  ldx #1
  lda MY_NONCE
  cmp PEER_NONCE
  lda MY_NONCE+1
  sbc PEER_NONCE+1
  bcs @seat
  ldx #0
@seat:
  stx MY_SEAT
  lda MY_FACTION
  sta CFG_FAC,x
  txa
  eor #1
  tax
  lda PEER_FACTION
  sta CFG_FAC,x
  jsr SendHello
  jmp StartBattle

; LinkNewTurn - nothing heard yet for this turn.
LinkNewTurn:
  stz HAVE_PLAN
  stz PEER_ACK
  rts

; EnterLinkWait - orders are in: send them and wait for the other machine.
EnterLinkWait:
  lda #ST_WAIT
  sta STATE
  jsr HideMarkers
  jsr UploadSprites
  jsr CanvasClear
  jsr ClearMessages
  lda #INK_WHITE
  sta TXT_INK
  lda #ROW_MSG2
  ldx #<TxtOrdersIn
  ldy #>TxtOrdersIn
  jsr Print
  lda #INK_GRAY
  sta TXT_INK
  lda #ROW_MSG3
  ldx #<TxtWaitOther
  ldy #>TxtWaitOther
  jsr Print
  lda #ROW_MSG4
  ldx #<TxtOtherCart
  ldy #>TxtOtherCart
  jsr Print
  jsr PrintQuit
  lda #LINK_RESEND
  sta LINK_T
  jmp SendPlan

LinkWaitFrame:
  jsr LinkPoll
  lda LINK_BAD
  beq @fine
  jmp LinkBroken
@fine:
  lda HAVE_PLAN
  beq @waiting
  lda PEER_ACK
  beq @waiting
  ; both machines have both plans
  lda MY_SEAT
  eor #1
  tax
  lda PEER_PLAN
  sta PLAN_C,x
  lda PEER_PLAN+1
  sta PLAN_R,x
  lda PEER_PLAN+2
  sta AIM_C,x
  lda PEER_PLAN+3
  sta AIM_R,x
  lda PEER_PLAN+4
  and #1
  sta PLAN_WEAPON,x
  lda PEER_PLAN+4
  lsr a
  sta PLAN_SPECIAL,x
  jmp PlayTurn
@waiting:
  lda EV_SWAP
  beq @timer
  jmp EnterTitle
@timer:
  dec LINK_T
  bne @done
  lda #LINK_RESEND
  sta LINK_T
  jmp SendPlan
@done:
  rts

; --- Sending ---

; SendFrame - TX_FRAME, with its sync and checksum.
SendFrame:
  lda #FRAME_SYNC
  sta TX_FRAME
  lda #<TX_FRAME
  ldx #>TX_FRAME
  jsr FrameCheck
  lda CK_A
  sta TX_FRAME + FRAME_SIZE - 2
  lda CK_B
  sta TX_FRAME + FRAME_SIZE - 1
  ldx #0
@send:
  lda TX_FRAME,x
  jsr SendByte
  inx
  cpx #FRAME_SIZE
  bne @send
  rts

; FrameCheck - CK_A, CK_B = the check of the frame at A (low), X (high). Two sums,
; the second over the first, so a frame put together from the pieces of two
; others, after a lost byte, doesn't pass by chance.
FrameCheck:
  sta SV_PTR
  stx SV_PTR+1
  lda #$5A
  sta CK_A
  lda #$A5
  sta CK_B
  ldy #1
@byte:
  lda (SV_PTR),y
  clc
  adc CK_A
  sta CK_A
  clc
  adc CK_B
  sta CK_B
  iny
  cpy #FRAME_SIZE - 2
  bne @byte
  rts

; SendByte - A out of the serial port, once the last byte has gone. Not the
; Kernal's routine: while it waits it puts arriving bytes in the keyboard buffer,
; where they'd read as key presses. Here they go in the ring. Keeps X.
SendByte:
  pha
  sei
@wait:
  lda SC_STATUS
  sta LINK_S
  and #SC_STATUS_RDRF
  beq @noByte
  phx
  lda SC_DATA
  ldx RX_HEAD
  sta RX_BUF,x
  inc RX_HEAD
  plx
@noByte:
  lda LINK_S
  and #SC_STATUS_TDRE
  beq @wait
  pla
  sta SC_DATA
  cli
  rts

; SendHello - who this machine is, and how far along: 0 looking, 1 has heard the
; other machine, 2 has started.
SendHello:
  lda #FR_HELLO
  sta TX_FRAME+1
  stz TX_FRAME+2
  lda MY_NONCE
  sta TX_FRAME+3
  lda MY_NONCE+1
  sta TX_FRAME+4
  lda MY_FACTION
  sta TX_FRAME+5
  lda LINK_UP
  beq @notUp
  lda #2
  bra @stage
@notUp:
  lda HAVE_HELLO
@stage:
  sta TX_FRAME+6
  lda #LINK_VERSION
  sta TX_FRAME+7
  stz TX_FRAME+8
  jmp SendFrame

SendPlan:
  ldx MY_SEAT
  lda #FR_PLAN
  sta TX_FRAME+1
  lda TURN
  sta TX_FRAME+2
  lda PLAN_C,x
  sta TX_FRAME+3
  lda PLAN_R,x
  sta TX_FRAME+4
  lda AIM_C,x
  sta TX_FRAME+5
  lda AIM_R,x
  sta TX_FRAME+6
  lda PLAN_SPECIAL,x
  asl a
  ora PLAN_WEAPON,x
  sta TX_FRAME+7
  jsr StateSum
  sta TX_FRAME+8
  jmp SendFrame

; SendAck - turn A's plan arrived.
SendAck:
  sta TX_FRAME+2
  lda #FR_ACK
  sta TX_FRAME+1
  ldx #3
@clear:
  stz TX_FRAME,x
  inx
  cpx #FRAME_SIZE - 2
  bne @clear
  jmp SendFrame

; StateSum - A = a checksum of everything a turn is played from.
StateSum:
  lda #0
  clc
  ldx N_SHIPS
  dex
@ship:
  adc SHIP_HP_LO,x
  adc SHIP_HP_HI,x
  adc SHIP_C,x
  adc SHIP_R,x
  adc SHIP_ALIVE,x
  adc SPECIAL_WAIT,x
  adc CLOAKED,x
  dex
  bpl @ship
  ldx #NUM_MINES - 1
@mine:
  adc MINE_OWNER,x
  adc MINE_C,x
  adc MINE_R,x
  dex
  bpl @mine
  rts

; --- Receiving ---

; LinkPoll - take what has arrived, a limited amount a frame.
LinkPoll:
  lda LINK_ON
  beq @done
  lda #POLL_BYTES
  sta LINK_N
@next:
  ldx RX_TAIL
  cpx RX_HEAD
  beq @done
  lda RX_BUF,x
  inc RX_TAIL
  ldx PARSE_N
  bne @inFrame
  cmp #FRAME_SYNC
  bne @count
@inFrame:
  sta FRAME,x
  inx
  stx PARSE_N
  cpx #FRAME_SIZE
  bne @count
  stz PARSE_N
  jsr TakeFrame
@count:
  dec LINK_N
  bne @next
@done:
  rts

; TakeFrame - check a whole frame and act on it.
TakeFrame:
  lda #<FRAME
  ldx #>FRAME
  jsr FrameCheck
  lda CK_A
  cmp FRAME + FRAME_SIZE - 2
  bne @done
  lda CK_B
  cmp FRAME + FRAME_SIZE - 1
  bne @done
  lda FRAME+1
  cmp #FR_HELLO
  beq TakeHello
  cmp #FR_PLAN
  beq TakePlan
  cmp #FR_ACK
  bne @done
  lda FRAME+2
  cmp TURN
  bne @done
  lda #1
  sta PEER_ACK
@done:
  rts

TakePlan:
  lda LINK_UP
  beq @done
  lda FRAME+2
  cmp TURN
  beq @now
  inc a                            ; last turn's, when our answer got lost
  cmp TURN
  beq @answer
@done:
  rts
@now:
  lda STATE                        ; after the battle the state has moved on
  cmp #ST_OVER
  beq @answer
  jsr StateSum
  cmp FRAME+8
  beq @same
  lda #BAD_SYNC
  sta LINK_BAD
  rts
@same:
  lda HAVE_PLAN
  bne @answer
  ldx #4
@copy:
  lda FRAME+3,x
  sta PEER_PLAN,x
  dex
  bpl @copy
  lda #1
  sta HAVE_PLAN
  lda STATE
  cmp #ST_PLAN
  bne @answer
  lda #INK_GRAY
  sta TXT_INK
  lda #ROW_READY
  ldx #<TxtOtherReady
  ldy #>TxtOtherReady
  jsr Print
@answer:
  lda FRAME+2
  jmp SendAck

TakeHello:
  lda FRAME+7
  cmp #LINK_VERSION
  beq @version
  lda #BAD_VERSION
  sta LINK_BAD
  rts
@version:
  lda LINK_UP
  beq @looking
  ; already playing: it may not know yet
  lda FRAME+3
  cmp PEER_NONCE
  bne @done
  lda FRAME+4
  cmp PEER_NONCE+1
  bne @done
  lda FRAME+6
  cmp #2
  bcs @done
  jmp SendHello
@looking:
  lda FRAME+3
  cmp MY_NONCE
  bne @other
  lda FRAME+4
  cmp MY_NONCE+1
  bne @other
  stz HAVE_HELLO                   ; the same number: both pick again
  stz PEER_HAS
  jmp NewNonce
@other:
  lda FRAME+3
  sta PEER_NONCE
  lda FRAME+4
  sta PEER_NONCE+1
  lda FRAME+5
  and #3
  sta PEER_FACTION
  lda #1
  sta HAVE_HELLO
  lda FRAME+6
  beq @answer
  lda #1
  sta PEER_HAS
@done:
  rts
@answer:
  jmp SendHello
