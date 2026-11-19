**Turn-based starship battles on a hex grid, for the AC6502 ACE.** Everyone plans in secret, then every ship moves and fires at once, so aim where your enemies are going, not where they are.

**[Play it in your browser at games.infinitetoken.com](https://games.infinitetoken.com/6502/hexfleet)**, in A.C. Wright's AC6502 emulator. Download the cartridge below to run it on your own ACE or in the emulator on your computer.

## Features

- Up to four ships: people and CPUs in any mix, all against all or in two teams
- Two ACEs linked over their serial ports, each player planning on their own screen
- Four factions, each with its own special: a flak shell, mines, a cloak or a jump
- Normal and Easy CPUs that think while you plan, so there's no waiting on them
- A top-five high score table saved to the cartridge
- Ships drawn from the HexFleet app's artwork, and the app's sound effects and music rebuilt for the SID

## What You Need

- An [AC6502 ACE](https://github.com/acwright/6502-ACE) with a [6502-PICOVDP](https://github.com/acwright/6502-PICOVDP) on BIOS 2.x, and a 128 KB Flash Cart. Sound needs the GPIO card as well as the sound card, since a timer on it keeps the music in time.
- Or the [AC6502 emulator](https://github.com/acwright/6502-EMULATOR), 3.0 or newer, with the video card set to PICOVDP. From a terminal: `6502 run --vdp picovdp --cart HexFleet.crt`

## Controls

Either joystick, or the keyboard:

- **Move the cursor:** the stick, or W A S D or the arrow keys
- **Pick:** A, or Space or Enter
- **Swap between Laser, Torpedo and your special:** B, or X

On your turn, pick a hex up to 3 away (your own hex holds position), pick a target, then press fire again to lock in. With a one-button stick, picking your destination again swaps instead.

## Factions

- **Vanguard, flak shell:** lobbed at a hex up to 5 away, it bursts as the ships stop, hitting every other ship within a hex
- **Raider, mine:** dropped where you start, along with your shot. Only you can see it. It arms halfway through the turn and blasts the first enemy that comes close
- **Swarm, cloak:** nobody sees you until the next turn plays, so they plan knowing only where you were last seen
- **Wraith, jump:** gone until halfway through the turn, then down up to 6 hexes away, hitting every ship around where you land

## High Scores

Beat the CPUs to score. A win, the hull you have left, how fast you won and how many enemies you took on all count, and the score is multiplied by 5 when no CPU was on Easy. Enter your initials and it's saved to the cartridge, so it's still there when you switch off.

## More HexFleet

HexFleet started as an app. The original, with online matches against your friends, plays in your browser at [games.infinitetoken.com/hexfleet](https://games.infinitetoken.com/hexfleet/), with iPhone, iPad and Android versions on the way. More of our games are at [games.infinitetoken.com](https://games.infinitetoken.com).

## Credits

Made by [Jay Deaton](https://jaydeaton.com). The AC6502 computers and emulator are by [A.C. Wright](https://acwrightdesign.itch.io). The source code is on [GitHub](https://github.com/jayrdeaton/6502-HexFleet), MIT licensed.
