import Connectable::*;
import SysConfig::*;
import AlteraJtagUart::*;
import AsyncPulseSync::*;
import Funnel::*;
import CycleCounter::*;
import StatusLED::*;
import SRAMSplit::*;
import SRAMFIFO::*;
import MAX5134::*;

typedef TSub#(AddrSize,1) FifoAddrSize;
typedef Bit#(AddrSize) Addr;
typedef Bit#(8) Byte;

typedef Bit#(TMul#(TimeStampBytes, 8)) TimeStamp;

interface AcqSys;
	(* prefix="" *)
	interface StatusLEDWires led_wires;
	(* prefix="SRAM" *)
	interface SRAMWires#(Addr, Byte) sram_wires;
	(* prefix="DAC" *)
	interface DACWires dac_wires;
	(* prefix="CH" *)
	interface Vector#(NumInputs, AcqIn) inputs;
endinterface

(* synthesize *)
module mkAcqSys(AcqSys);
	AlteraJtagUart uart <- mkAlteraJtagUart(1, 1);

	SRAMSplit#(AddrSize, Byte) sram <- mkSRAMSplit;
	SRAMFIFO#(FifoAddrSize, Byte) uartInFifo  <- mkSRAMFIFO;
	SRAMFIFO#(FifoAddrSize, Byte) uartOutFifo <- mkSRAMFIFO;

	DAC dac <- mkDAC;
	Reg#(DACMask) dacPending <- mkReg(0);

	Vector#(NumInputs, SyncPulseIfc) inSyncs <- replicateM(mkAsyncPulseSync);
	Bit#(NumInputs) syncedIn = fromPulseVector(inSyncs);

	CycleCounter#(CyclesResolution) cycleCounter <- mkCycleCounter;
	StatusLED#(4) led <- mkStatusLED(syncedIn, cycleCounter.ticked);
	Reg#(Bool) acqStarted <- mkReg(False);
	Reg#(TimeStamp) timestamp <- mkReg(0);
	Array#(Reg#(Bit#(NumInputs))) channelFlags <- mkCReg(2, 0);

	Funnel#(Tuple2#(Byte, TimeStamp), Byte) funnel   <- mkFunnel;
	Funnel#(Byte, Tuple2#(Byte, DACSample)) unfunnel <- mkUnfunnel;
	Reg#(UInt#(2)) uartBytesBeforeCmd <- mkReg(0);

	mkConnection(sram.srvA, uartInFifo.cli);
	mkConnection(sram.srvB, uartOutFifo.cli);

	mkConnection(toGet(uartOutFifo.fifo), uart.tx);

	mkConnection(toGet(uartInFifo.fifo), unfunnel.in);
	mkConnection(funnel.out, toPut(uartOutFifo.fifo));

	rule uartHandleCmd(uartBytesBeforeCmd == 0);
		let cmd <- uart.rx.get;
		(*split*)
		case(cmd) matches
			8'b1000_0000: acqStarted <= True;
			8'b0000_????:
				action
					uartInFifo.fifo.enq(cmd);
					uartBytesBeforeCmd <= 2;
				endaction
			default: led.errorCondition[3].set;  // invalid command
		endcase
	endrule

	rule uartCopy(uartBytesBeforeCmd != 0);
		let data <- uart.rx.get;
		uartInFifo.fifo.enq(data);
		uartBytesBeforeCmd <= uartBytesBeforeCmd - 1;
	endrule

	(* descending_urgency="dacLoad, dacHandleReq" *)	
	rule dacHandleReq;
		match {.cmd, .sample} <- unfunnel.out.get;
		let chmask = cmd[3:0];
		if(cmd[7:4] != 4'b0)
			// should never happen, SRAM communication failure?
			led.errorCondition[2].set;
		when((chmask & dacPending) == 4'b0, action
			dac.req.put(tuple2(chmask, sample));
			dacPending <= dacPending | chmask;
		endaction);
	endrule

	(* fire_when_enabled *)
	rule dacLoad(acqStarted && syncedIn[0] == 1'b1);
		(*split*)
		if(!dac.isReady || reduceAnd(dacPending)==1'b0) begin
			led.errorCondition[1].set;  // RX FIFO underrun
		end else begin
			dac.load;
		end
		dacPending <= 0;
	endrule

	(* fire_when_enabled *)
	rule timestampUpdate(acqStarted && cycleCounter.ticked);
		let flags = asReg(channelFlags[0]);
		(*split*)
		if(flags != 0) begin
			(*split*)
			if(funnel.notFull)
				funnel.in.put(tuple2(extend(flags), timestamp));
			else
				led.errorCondition[0].set;  // TX FIFO overflow
		end
		flags <= 0;
		timestamp <= timestamp + 1;
	endrule

	(* fire_when_enabled, no_implicit_conditions *)
	rule blendChannelFlags(acqStarted);
		channelFlags[1] <= channelFlags[1] | syncedIn;
	endrule

	interface led_wires = led.wires;
	interface sram_wires = sram.wires;
	interface dac_wires = dac.wires;
	interface inputs = Vector::map(toAcqIn, inSyncs);
endmodule
