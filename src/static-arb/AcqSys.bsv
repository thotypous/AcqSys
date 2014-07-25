import Connectable::*;
import SysConfig::*;
import AlteraJtagUart::*;
import AsyncPulseSync::*;
import Funnel::*;
import CentralArbiter::*;
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

	CentralArbiter#(8) arb <- mkCentralArbiter;
	SRAMSplit#(AddrSize, Byte) sram <- mkSRAMSplit(arb.turn[2], arb.turn[0], arb.turn == 5, arb.turn == 7);
	SRAMFIFO#(FifoAddrSize, Byte) uartInFifo  <- mkSRAMFIFO(arb.turn == 2, arb.turn == 0);
	SRAMFIFO#(FifoAddrSize, Byte) uartOutFifo <- mkSRAMFIFO(arb.turn == 4, arb.turn == 6);

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

	(* fire_when_enabled *)
	rule uartInFifo_cli_request_to_sram_srvA;
		let x <- uartInFifo.cli.request.get;
		sram.srvA.request.put(x);
	endrule
	(* fire_when_enabled *)
	rule sram_srvA_response_to_uartInFifo_cli;
		let x <- sram.srvA.response.get;
		uartInFifo.cli.response.put(x);
	endrule

	(* fire_when_enabled *)
	rule uartOutFifo_cli_request_to_sram_srvB;
		let x <- uartOutFifo.cli.request.get;
		sram.srvB.request.put(x);
	endrule
	(* fire_when_enabled *)
	rule sram_srvB_response_to_uartOutFifo_cli;
		let x <- sram.srvB.response.get;
		uartOutFifo.cli.response.put(x);
	endrule

	rule uartOutFifo_fifo_to_uart_tx;
		let x <- toGet(uartOutFifo.fifo).get;
		uart.tx.put(x);
	endrule

	rule uartInFifo_fifo_to_unfunnel_in;
		let x <- toGet(uartInFifo.fifo).get;
		unfunnel.in.put(x);
	endrule

	rule funnel_out_to_uartOutFifo_fifo;
		let x <- funnel.out.get;
		toPut(uartOutFifo.fifo).put(x);
	endrule

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
