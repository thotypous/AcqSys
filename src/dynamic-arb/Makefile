BSCFLAGS=-no-lift -aggressive-conditions
BSCHARDFLAGS=-opt-undetermined-vals -unspecified-to X
BSVPATH=../common:+

include ../common/quartus.mk

all: mkAcqSys.v pof
mkAcqSys.v:
	mkdir -p obj
	bsc -u -bdir obj -p $(BSVPATH) -show-schedule -verilog $(BSCFLAGS) $(BSCHARDFLAGS) AcqSys.bsv
emu:
	mkdir -p obj-emu verilog-emu
	cp ../common/*.v verilog-emu
	bsc -u -bdir obj-emu -p ../emu:$(BSVPATH) -verilog $(BSCFLAGS) -vdir verilog-emu ../emu/EmuTop.bsv
	bsc -verilog -vdir verilog-emu -e mkEmuTop -o emulate
clean:
	rm -rf obj obj-emu verilog-emu $(QUARTUS_BUILD_DIR)
	rm -f emulate *.v *.sched
