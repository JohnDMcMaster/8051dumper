# Assemble the 8051dumper firmware with tpasm http://www.sqrt.com/

all: 8051dumper_filled.hex

.PHONY: clean

# Fill unused portions of ROM with pattern that will stand out when
# analyzing dumped code
8051dumper_filled.hex: 8051dumper.hex
	./fill.py 8051dumper.hex 8051dumper_filled.hex

# Assemble firmware
8051dumper.hex: 8051dumper.asm SFR.asm
	tpasm -o intel 8051dumper.hex -l 8051dumper.lst 8051dumper.asm

# Clean up output files
clean:
	$(RM) 8051dumper_filled.hex
	$(RM) 8051dumper.hex
	$(RM) 8051dumper.lst
