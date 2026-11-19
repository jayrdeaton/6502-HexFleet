HexFleet
========

HexFleet for the [AC6502 ACE](https://github.com/acwright/6502-ACE): the hex
fleet battle from the HexFleet app, as a cartridge for one player against the CPU,
two players on one machine, or two machines linked over their serial ports. Everyone plans in secret, then every ship moves and
fires at once.

It runs on an ACE with a [6502-PICOVDP](https://github.com/acwright/6502-PICOVDP)
on BIOS 2.x, as a 128 KB Flash Cart.

## Playing it

Load `HexFleet.crt` in the [AC6502 emulator](https://github.com/acwright/6502-EMULATOR)
(3.0 or newer) with the video card set to PICOVDP, or from a terminal:

```sh
6502 run --vdp picovdp --cart HexFleet.crt
```

## Controls

Either joystick, or the keyboard:

| | Joystick | Keyboard |
| --- | --- | --- |
| Move the cursor | Stick | W A S D or the arrow keys |
| Pick | A | Space or Enter |
| Swap Laser, Torpedo and your special | B | X |

On the title screen, up and down choose a line, and left and right change it: each
ship's faction, and the opponent (Normal CPU, Easy CPU, 2 Players or Link).

On your turn, pick a hex up to 3 away (your own hex holds position), pick a target,
then press fire again to lock in. Picking your destination again also swaps, for
one-button sticks, and picking your ship goes back to the move.

## Sound

The app's sound effects and its menu and battle music, rebuilt for the SID's three
voices (`tools/build-sound.mjs`). Music plays on all three. An effect takes over a voice
and the music picks it up again at its next note. The title screen's Music line turns
the music off. Sound needs the machine's GPIO card as well as the sound card, because a
timer on it keeps the music in time.

## Specials

Each faction has one. Swap to it while you plan; the panel shows when it's ready.

| Faction | Special | What it does | Recharge |
| --- | --- | --- | --- |
| Vanguard | Flak shell | In place of your shot. Lands on a hex up to 5 away as ships stop, 45 to every other ship within a hex | 1 turn |
| Raider | Mine | Goes with your shot. Drops where you start, seen only by you, arms halfway through the turn, and blasts the first enemy within a hex for 25. 3 at most | 3 turns |
| Swarm | Cloak | In place of your shot. Nobody sees you until the next turn plays, and they plan knowing only where you were last seen. Hits still land, and show where you are | 1 turn |
| Wraith | Jump | In place of your move and shot. Gone until halfway through the turn, then lands up to 6 hexes away: 20 to a ship next to you, or 40 to one you land on and 20 to yourself | 5 turns |

## High scores

Beat the CPU and your score goes on the table if it's in the best five: enter three
initials with up and down, and it's saved to the Flash Cart, so it's still there when
you switch off.

A win scores 100, plus your hull left as a percentage, plus 5 for every turn under 20.
Against the Normal CPU that's multiplied by 5, so the best possible score is 1475 and
an Easy win never outranks a Normal one. Two-player battles don't score.

In the emulator the table is kept in `HexFleet.sav` beside the cartridge. A rebuilt
cartridge won't load a save from an older build.

## Playing over a cable

Join two ACEs' serial ports with a null-modem cable (each machine's transmit to the
other's receive, and ground to ground). Each player sets Opponent to Link, picks a ship
and presses fire; the battle starts when both have. Each player plans on their own
screen and sees only their own mines and cloak. The machines send each other the plans,
so they stay in step. Damaged bytes are sent again, and if the machines ever disagree
they stop and say so. While waiting, B or X goes back to the menu.

Both machines need the same build of the cartridge. Linked battles don't score.

## What's here so far

One player against a Normal or Easy CPU, or two players on one machine or two, with the four factions' hulls,
torpedoes and specials, moves, lasers, hits by contact, the end of the battle, a saved
high score table and two-machine play over the serial port.

The CPU plans from the board as the turn began and never sees your plan, your mines or
a cloaked ship (only where it was last seen). It thinks a slice at a time while you
plan (`src/ai.asm`, `src/special.asm`), so there's no wait.

## Building

Needs [cc65](https://cc65.github.io/) and [6502-Lib](https://github.com/jayrdeaton/6502-Lib)
beside this folder.

```sh
make          # builds HexFleet.crt
make assets   # redraws src/assets.inc (needs ../HexFleet and a built ../Pixelated)
              # and src/sounddata.inc
```

The generated files are committed, so `make` alone needs only cc65 and 6502-Lib. The
ship sprites are the HexFleet app's own artwork and hull textures, turned into 16x16
PICOVDP sprites by Pixelated, one for each of the 12 headings and lit from the top left
as in the app.

Everything that touches the hardware is in `src/vdp.asm`, `src/input.asm`,
`src/sound.asm` (with the interrupt handler), the flash routines in `src/scores.asm` and the serial routines in
`src/link.asm`, so another machine can replace those.

## License

The code is released under the MIT License, see [LICENSE](LICENSE).

The game's name, logo, and icons, and the original artwork and audio in this repository, are not covered by that license and remain all rights reserved. If you fork it, please give your version its own name and look.
