#!/bin/sh
# The usual set: the rules, the CPUs, the high score table, a save cut short at
# a dozen points, and two machines linked over a clean and a noisy cable.
# Needs a built HexFleet.crt (make) and emulator 3.0 or newer (see emulator.mjs).
cd "$(dirname "$0")" || exit 1
status=0
node spec.mjs defaults torpedo flak mine cloak jump cpuview soak scores seats4 mate perf4 perf outline || status=1
NO_SAVE=1 CUTS=0,30,50,60,70,90,120,200,400,800,1500,3000 node spec.mjs cuts || status=1
node link.mjs basic hidden cable alone title || status=1
ONE=1 node link.mjs play || status=1
exit $status
