SEED ?= gun

.PHONY:
	build run clean

build: boot.asm
	nasm -f bin -o boot.bin boot.asm -DSEED_FILE='"./patterns/$(SEED).inc"'

run: boot.bin
	qemu-system-x86_64 -drive format=raw,file=boot.bin

clean:
	rm -f boot.bin
