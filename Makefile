TARGET = HexFleet
CONFIG = 6502-128K

.PHONY: all build assets run clean

all: build

build: $(TARGET).crt

$(TARGET).crt: $(TARGET).asm $(CONFIG).cfg 6502-VDP.inc $(wildcard src/*)
	cl65 -t none -C $(CONFIG).cfg -l $(TARGET).lst -m $(TARGET).map -o $(TARGET).crt $(TARGET).asm

# The sprites and board tiles (needs ../HexFleet and ../Pixelated), and the sound data
assets:
	node tools/build-assets.mjs
	node tools/build-sound.mjs

run: build
	6502 run --vdp picovdp --cart $(TARGET).crt

clean:
	rm -f $(TARGET).crt $(TARGET).lst $(TARGET).map *.o src/*.o
