; =============================================================================
;   scores.asm - the high score table, saved on the Flash Cart
; =============================================================================
;   One person beating the CPUs scores 100, plus their hull left as a percentage,
;   plus 5 for every turn under 20, plus 100 for each enemy past the first. With no
;   Easy CPU in the battle that's worth 5 times as much. The best five are kept.
;
;   The table lives in the cart's save sector, the top 4 KB of bank $0E, as a
;   log of 64-byte records. Each save goes in the next free record, so a power
;   cut while saving only loses that save, and the sector is erased once every
;   64 saves rather than every time. Loading takes the last record that checks
;   out. A record: "HF", a version, 5 entries of 8 bytes, a checksum.
;
;   While the flash chip is erasing or programming, every read of it returns
;   status, the fixed bank included. So the writing routine is copied to RAM and
;   runs there with interrupts off, and it may only use relative branches.
; =============================================================================

.segment "CART"

SAVE_BANK     = $0E
SAVE_ADDR     = $D000
UNLOCK1_BANK  = $02
UNLOCK1       = $D555              ; flash $5555
UNLOCK2_BANK  = $01
UNLOCK2       = $CAAA              ; flash $2AAA
SLOT_COUNT    = 64
SAVE_VERSION  = 1
NUM_SCORES    = 5
ENTRY_SIZE    = 8
ENTRIES       = SAVE_BUF + 3
SUM_AT        = 3 + NUM_SCORES * ENTRY_SIZE
SAVE_SIZE     = SUM_AT + 1

; An entry's bytes
E_LO          = 0
E_HI          = 1
E_NAME        = 2
E_FACTION     = 5
E_OPP         = 6
E_TURNS       = 7

TxtHighScores: .asciiz "HIGH SCORES"
TxtNewRecord:  .asciiz "NEW RECORD"
TxtScore:      .asciiz "SCORE "
TxtRank:       .asciiz "RANK "
TxtUpDownLtr:  .asciiz "UP/DN: LTR"
TxtFireNext:   .asciiz "FIRE: NEXT"
TxtSaved:      .asciiz "SAVED"
TxtNotSaved:   .asciiz "NOT SAVED"
TxtNoScore:    .asciiz "---"

PowLo:
  .byte <1000, <100, <10, <1
PowHi:
  .byte >1000, >100, >10, >1

; --- Loading ---

; SlotAddr - SV_PTR = where record A lives in the window.
SlotAddr:
  pha
  and #3
  asl a
  asl a
  asl a
  asl a
  asl a
  asl a
  sta SV_PTR
  pla
  lsr a
  lsr a
  clc
  adc #>SAVE_ADDR
  sta SV_PTR+1
  rts

; RecordSum - A = the checksum of the record at SV_PTR.
RecordSum:
  ldy #0
  lda #$5A
  clc
@byte:
  adc (SV_PTR),y
  iny
  cpy #SUM_AT
  bne @byte
  rts

; RecordValid - carry set if the record at SV_PTR checks out.
RecordValid:
  lda (SV_PTR)
  cmp #'H'
  bne @no
  ldy #1
  lda (SV_PTR),y
  cmp #'F'
  bne @no
  iny
  lda (SV_PTR),y
  cmp #SAVE_VERSION
  bne @no
  jsr RecordSum
  ldy #SUM_AT
  cmp (SV_PTR),y
  bne @no
  sec
  rts
@no:
  clc
  rts

; LoadScores - the newest good record into SAVE_BUF, or an empty table; SV_SLOT
; is left on the first free record (SLOT_COUNT if there's none).
LoadScores:
  ldx #SAVE_SIZE - 1
@clear:
  stz SAVE_BUF,x
  dex
  bpl @clear
  lda #'A'
  sta NAME_BUF
  sta NAME_BUF+1
  sta NAME_BUF+2
  lda #SAVE_BANK
  jsr SetBank
  stz SV_SLOT
@slot:
  lda SV_SLOT
  jsr SlotAddr
  lda (SV_PTR)
  cmp #$FF
  beq @done                        ; never written: the log ends here
  jsr RecordValid
  bcc @next
  ldy #SUM_AT
@copy:
  lda (SV_PTR),y
  sta SAVE_BUF,y
  dey
  bpl @copy
@next:
  inc SV_SLOT
  lda SV_SLOT
  cmp #SLOT_COUNT
  bne @slot
@done:
  lda #0
  jmp SetBank

; --- Saving ---

; SaveScores - SAVE_BUF into the next record. Carry set if it reads back right.
SaveScores:
  lda #'H'
  sta SAVE_BUF
  lda #'F'
  sta SAVE_BUF+1
  lda #SAVE_VERSION
  sta SAVE_BUF+2
  lda #<SAVE_BUF
  sta SV_PTR
  lda #>SAVE_BUF
  sta SV_PTR+1
  jsr RecordSum
  sta SAVE_BUF + SUM_AT
  stz SV_ERASE
  lda SV_SLOT
  cmp #SLOT_COUNT
  bcc @room
  inc SV_ERASE                     ; the log is full: start it again
  stz SV_SLOT
@room:
  lda SV_SLOT
  jsr SlotAddr
  ldx #RamWriteEnd - RamWrite - 1
@copy:
  lda RamWrite,x
  sta SAVE_CODE,x
  dex
  cpx #$FF
  bne @copy
  jsr SAVE_CODE
  inc SV_SLOT
  lda #SAVE_BANK
  jsr SetBank
  ldy #SUM_AT
@verify:
  lda (SV_PTR),y
  cmp SAVE_BUF,y
  bne @bad
  dey
  bpl @verify
  lda #0
  jsr SetBank
  sec
  rts
@bad:
  lda #0
  jsr SetBank
  clc
  rts

; RamWrite - runs at SAVE_CODE. Erases the sector if SV_ERASE, then programs
; SAVE_BUF at (SV_PTR). Every wait gives up in time, so a cart that won't take
; the write can't hang the game; SaveScores' read-back catches it.
RamWrite:
  sei
  lda SV_ERASE
  beq @program
  lda #UNLOCK1_BANK
  sta BANK
  lda #$AA
  sta UNLOCK1
  lda #UNLOCK2_BANK
  sta BANK
  lda #$55
  sta UNLOCK2
  lda #UNLOCK1_BANK
  sta BANK
  lda #$80
  sta UNLOCK1
  lda #$AA
  sta UNLOCK1
  lda #UNLOCK2_BANK
  sta BANK
  lda #$55
  sta UNLOCK2
  lda #SAVE_BANK
  sta BANK
  lda #$30
  sta SAVE_ADDR
  ldx #0
  ldy #0
@erasing:
  lda SAVE_ADDR                    ; bit 7 reads 0 until the erase is done
  bmi @program
  dex
  bne @erasing
  dey
  bne @erasing
@program:
  ldy #0
@byte:
  lda SAVE_BUF,y
  cmp #$FF
  beq @next                        ; erased flash already holds it
  lda #UNLOCK1_BANK
  sta BANK
  lda #$AA
  sta UNLOCK1
  lda #UNLOCK2_BANK
  sta BANK
  lda #$55
  sta UNLOCK2
  lda #UNLOCK1_BANK
  sta BANK
  lda #$A0
  sta UNLOCK1
  lda #SAVE_BANK
  sta BANK
  lda SAVE_BUF,y
  sta (SV_PTR),y
  ldx #0
@writing:
  lda (SV_PTR),y                   ; bit 7 is inverted until the byte is done
  eor SAVE_BUF,y
  bpl @next
  dex
  bne @writing
@next:
  iny
  cpy #SAVE_SIZE
  bne @byte
  lda BANKSHDW
  sta BANK
  cli
  rts
RamWriteEnd:
.assert RamWriteEnd - RamWrite < 256, error, "the flash routine no longer fits its page"

; --- Scoring ---

; CheckRecord - after a battle: carry set if you beat the CPU with a score that
; makes the table, with NEW_SCORE and RANK set.
CheckRecord:
  lda HUMANS
  cmp #1
  bne @none
  jsr IsLink
  beq @none
  ldy WINNER
  cpy #$FF
  beq @none
  ldx HUMAN_SEAT
  lda SHIP_SIDE,y
  cmp SHIP_SIDE,x
  beq @won
@none:
  clc
  rts
@won:
  ; 100, plus the hull left as a percentage
  lda SHIP_HP_HI,x
  phx
  ldx #100
  jsr Mul8
  plx
  lda PROD
  sta DIVIDEND
  lda PROD+1
  sta DIVIDEND+1
  ldy SHIP_FACTION,x
  lda MaxHull,y
  sta DIVISOR
  jsr Div16
  lda QUOT
  clc
  adc #100
  sta NEW_SCORE
  stz NEW_SCORE+1
  ; plus 5 a turn under 20
  lda TURN
  cmp #20
  bcs @counted
  lda #20
  sec
  sbc TURN
  ldx #5
  jsr Mul8
  lda PROD
  clc
  adc NEW_SCORE
  sta NEW_SCORE
  bcc @counted
  inc NEW_SCORE+1
@counted:
  ; plus 100 for each enemy past the first, and is any CPU an easy one?
  stz T2
  ldy HUMAN_SEAT
  ldx N_SHIPS
@seat:
  dex
  bmi @seats
  lda SEAT_KIND,x
  cmp #KIND_EASY
  bne @notEasy
  inc T2
@notEasy:
  lda SHIP_SIDE,x
  cmp SHIP_SIDE,y
  beq @seat
  lda NEW_SCORE
  clc
  adc #100
  sta NEW_SCORE
  bcc @seat
  inc NEW_SCORE+1
  bra @seat
@seats:
  lda NEW_SCORE                    ; the first enemy doesn't add anything
  sec
  sbc #100
  sta NEW_SCORE
  bcs @kinds
  dec NEW_SCORE+1
@kinds:
  lda T2
  bne @rank
  ; times 5 against Normal CPUs
  lda NEW_SCORE
  sta T0
  lda NEW_SCORE+1
  sta T1
  asl NEW_SCORE
  rol NEW_SCORE+1
  asl NEW_SCORE
  rol NEW_SCORE+1
  lda NEW_SCORE
  clc
  adc T0
  sta NEW_SCORE
  lda NEW_SCORE+1
  adc T1
  sta NEW_SCORE+1
@rank:
  stz RANK
  ldy #0
@entry:
  lda ENTRIES + E_LO,y
  cmp NEW_SCORE
  lda ENTRIES + E_HI,y
  sbc NEW_SCORE+1
  bcc @yes                         ; this entry is lower: you go above it
  tya
  clc
  adc #ENTRY_SIZE
  tay
  inc RANK
  lda RANK
  cmp #NUM_SCORES
  bne @entry
  clc
  rts
@yes:
  sec
  rts

; InsertScore - NEW_SCORE and NAME_BUF into the table at RANK.
InsertScore:
  ldx #(NUM_SCORES - 1) * ENTRY_SIZE - 1
  lda RANK
  asl a
  asl a
  asl a
  sta T0
@shift:
  cpx T0
  bcc @place
  beq @last
  lda ENTRIES,x
  sta ENTRIES + ENTRY_SIZE,x
  dex
  bra @shift
@last:
  lda ENTRIES,x
  sta ENTRIES + ENTRY_SIZE,x
@place:
  ldy T0
  lda NEW_SCORE
  sta ENTRIES + E_LO,y
  lda NEW_SCORE+1
  sta ENTRIES + E_HI,y
  lda NAME_BUF
  sta ENTRIES + E_NAME,y
  lda NAME_BUF+1
  sta ENTRIES + E_NAME + 1,y
  lda NAME_BUF+2
  sta ENTRIES + E_NAME + 2,y
  ldx HUMAN_SEAT
  lda SHIP_FACTION,x
  sta ENTRIES + E_FACTION,y
  lda MODE
  sta ENTRIES + E_OPP,y
  lda TURN
  sta ENTRIES + E_TURNS,y
  rts

; --- On screen ---

; LineScore - DSQ as 4 characters, leading spaces. Keeps nothing.
LineScore:
  ldy #0
  stz T2
@place:
  stz T1
@sub:
  lda DSQ
  sec
  sbc PowLo,y
  sta T0
  lda DSQ+1
  sbc PowHi,y
  bcc @digit
  sta DSQ+1
  lda T0
  sta DSQ
  inc T1
  bra @sub
@digit:
  lda T1
  bne @show
  cpy #3
  beq @show
  lda T2
  bne @show
  lda #' '
  bra @put
@show:
  inc T2
  lda T1
  ora #'0'
@put:
  jsr LineChar
  iny
  cpy #4
  bne @place
  rts

; DrawScores - the table, on the panel's lower rows.
DrawScores:
  lda #INK_GRAY
  sta TXT_INK
  lda #ROW_SCORES
  ldx #<TxtHighScores
  ldy #>TxtHighScores
  jsr Print
  stz MN_I
  stz MN_OLD
@entry:
  jsr LineStart
  lda MN_I
  clc
  adc #'1'
  jsr LineChar
  lda #' '
  jsr LineChar
  ldy MN_OLD
  lda ENTRIES + E_LO,y
  sta DSQ
  lda ENTRIES + E_HI,y
  sta DSQ+1
  ora DSQ
  bne @used
  lda #INK_GRAY
  sta TXT_INK
  ldx #<TxtNoScore
  ldy #>TxtNoScore
  jsr LineStr
  bra @show
@used:
  ldx ENTRIES + E_FACTION,y
  lda SeatInk,x
  sta TXT_INK
  lda ENTRIES + E_NAME,y
  jsr LineChar
  lda ENTRIES + E_NAME + 1,y
  jsr LineChar
  lda ENTRIES + E_NAME + 2,y
  jsr LineChar
  lda #' '
  jsr LineChar
  jsr LineScore
@show:
  lda MN_I
  clc
  adc #ROW_SCORES + 1
  jsr LineShow
  lda MN_OLD
  clc
  adc #ENTRY_SIZE
  sta MN_OLD
  inc MN_I
  lda MN_I
  cmp #NUM_SCORES
  bne @entry
  rts

; ShowOver - the end of a battle's panel.
ShowOver:
  lda #INK_WHITE
  sta TXT_INK
  lda #ROW_MSG2
  ldx #<TxtGameOver
  ldy #>TxtGameOver
  jsr Print
  lda #ROW_MSG3
  ldx #<TxtFireMenu
  ldy #>TxtFireMenu
  jsr Print
  jmp DrawScores

; --- Entering initials ---

EnterName:
  lda #ST_NAME
  sta STATE
  stz NAME_POS
  jsr ClearMessages
  lda #INK_YELLOW
  sta TXT_INK
  lda #ROW_MSG1
  ldx #<TxtNewRecord
  ldy #>TxtNewRecord
  jsr Print
  lda #INK_WHITE
  sta TXT_INK
  jsr LineStart
  ldx #<TxtScore
  ldy #>TxtScore
  jsr LineStr
  lda NEW_SCORE
  sta DSQ
  lda NEW_SCORE+1
  sta DSQ+1
  jsr LineScore
  lda #ROW_MSG2
  jsr LineShow
  jsr LineStart
  ldx #<TxtRank
  ldy #>TxtRank
  jsr LineStr
  lda RANK
  clc
  adc #'1'
  jsr LineChar
  lda #ROW_MSG3
  jsr LineShow
  lda #INK_GRAY
  sta TXT_INK
  lda #ROW_MSG6
  ldx #<TxtUpDownLtr
  ldy #>TxtUpDownLtr
  jsr Print
  lda #ROW_MSG7
  ldx #<TxtFireNext
  ldy #>TxtFireNext
  jsr Print
  ; falls through

; DrawName - the three letters, with a mark under the one being set.
DrawName:
  lda #INK_WHITE
  sta TXT_INK
  jsr LineStart
  ldy #0
@letter:
  lda NAME_BUF,y
  jsr LineChar
  lda #' '
  jsr LineChar
  iny
  cpy #3
  bne @letter
  lda #ROW_MSG4
  jsr LineShow
  lda #INK_YELLOW
  sta TXT_INK
  jsr LineStart
  ldy NAME_POS
@pad:
  beq @mark
  lda #' '
  jsr LineChar
  lda #' '
  jsr LineChar
  dey
  bra @pad
@mark:
  lda #'^'
  jsr LineChar
  lda #ROW_MSG5
  jmp LineShow

NameFrame:
  lda EV_DIR
  cmp #NO_DIR
  beq @noDir
  ldx NAME_POS
  cmp #DIR_UP
  beq @up
  cmp #DIR_DOWN
  beq @down
  cmp #DIR_LEFT
  beq @left
  cpx #2                           ; right
  beq @noDir
  inc NAME_POS
  bra @moved
@left:
  cpx #0
  beq @noDir
  dec NAME_POS
  bra @moved
@up:
  lda NAME_BUF,x
  inc a
  cmp #'Z' + 1
  bne @set
  lda #'A'
  bra @set
@down:
  lda NAME_BUF,x
  dec a
  cmp #'A'
  bcs @set
  lda #'Z'
@set:
  sta NAME_BUF,x
@moved:
  jsr SndBack
  jsr DrawName
@noDir:
  lda EV_FIRE
  beq @done
  jsr SndPick
  lda NAME_POS
  cmp #2
  beq @finish
  inc NAME_POS
  jmp DrawName
@finish:
  jsr InsertScore
  jsr SaveScores
  php
  lda #ST_OVER
  sta STATE
  jsr ClearMessages
  plp
  bcs @saved
  lda #INK_RED
  sta TXT_INK
  lda #ROW_MSG1
  ldx #<TxtNotSaved
  ldy #>TxtNotSaved
  bra @say
@saved:
  lda #INK_GREEN
  sta TXT_INK
  lda #ROW_MSG1
  ldx #<TxtSaved
  ldy #>TxtSaved
@say:
  jsr Print
  jmp ShowOver
@done:
  rts
