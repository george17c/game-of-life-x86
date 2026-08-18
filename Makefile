FILE = boot

.PHONY:
	build run clean

build:
	nasm -f bin -o $(FILE).bin $(FILE).asm

run:
	qemu-system-x86_64 -drive format=raw,file=$(FILE).bin

clean:
	rm -f $(FILE).bin
