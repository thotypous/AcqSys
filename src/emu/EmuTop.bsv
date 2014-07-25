import Connectable::*;
import TriState::*;
import BRAM::*;
import FIFOF::*;
import Vector::*;
import StmtFSM::*;
import PCIE::*; // for byteSwap
import SysConfig::*;
import AsyncPulseSync::*;
import CycleCounter::*;
import StatusLED::*;
import SRAM2CLK::*;
import MAX5134::*;
import AcqSys::*;

typedef Bit#(AddrSize) Addr;
typedef Bit#(8) Byte;
typedef Bit#(TMul#(TimeStampBytes, 8)) TimeStamp;
typedef Tuple2#(Byte, TimeStamp) InputEnt;

(* synthesize *)
module mkEmuTop();
	AcqSys dut <- mkAcqSys;

	Wire#(Byte) data_out <- mkDWire(0);
	Bool isWrite = dut.sram_wires.nwe == 1'b0;
	TriState#(Byte) zdata <- mkTriState(!isWrite, data_out);
	mkConnection(dut.sram_wires.data, zdata.io);

	BRAM1Port#(Addr, Byte) bram <- mkBRAM1Server(defaultValue);
	FIFOF#(void) bram_pending_read <- mkFIFOF;

	Bool dac_selected = dut.dac_wires.nCS == 1'b0;
	Reg#(Bit#(1)) prev_sCLK <- mkReg(1'b1);
	Reg#(Bit#(1)) prev_nLDAC <- mkReg(1'b1);
	Array#(Reg#(Bool)) dac_blocked <- mkCReg(2, False);
	Reg#(Bit#(25)) dac_shiftreg <- mkReg(25'b1);

	Maybe#(Bit#(24)) dac_cmd = dac_shiftreg[24] == 1'b1 ?
		tagged Valid dac_shiftreg[23:0] : tagged Invalid;
	Vector#(DACChans, Reg#(DACSample)) dac_regs <- replicateM(mkRegU);

	FIFOF#(InputEnt) input_fifo <- mkLFIFOF;
	Reg#(TimeStamp) timestamp <- mkReg(0);

	rule timestamp_update;
		// Please note that this module works with timestamps
		// with a higher resolution than AcqSys, as they are
		// incremented every cycle, instead of being incremented
		// every CyclesResolution cycles.
		timestamp <= timestamp + 1;
	endrule

	let dac_fh   <- mkReg(InvalidFile);
	let input_fh <- mkReg(InvalidFile);
	Once openFiles <- mkOnce(action
		let fh <- $fopen("dump.dac", "wb");
		dac_fh <= fh;
		fh <- $fopen("dump.input", "rb");
		input_fh <= fh;
	endaction);

	rule open_files;
		openFiles.start;
	endrule

	function ActionValue#(Byte) read_input();
		return when(input_fh != InvalidFile, actionvalue
			let b <- $fgetc(input_fh);
			if(b < 0)
				$finish(0);  // EOF
			return truncate(pack(b));
		endactionvalue);
	endfunction

	rule read_input_ent;
		let mask <- read_input;
		TimeStamp tstamp = 0;
		for(Integer i = 8*valueOf(TimeStampBytes) - 1; i >= 0; i = i - 8)
			tstamp[i:i-7] <- read_input;
		input_fifo.enq(tuple2(mask, tstamp));
	endrule

	rule send_signals;
		match {.mask, .tstamp} = input_fifo.first;
		if(tstamp == timestamp) begin
			for(Integer i = 0; i < valueOf(NumInputs); i = i + 1)
				if(mask[i] == 1'b1)
					dut.inputs[i].send;
			input_fifo.deq;
		end
	endrule

	rule dac_unselect(!dac_selected);
		dac_shiftreg <= 25'b1;
		dac_blocked[1] <= False;
	endrule

	rule dac_update_prev;
		prev_sCLK  <= dut.dac_wires.sCLK;
		prev_nLDAC <= dut.dac_wires.nLDAC;
	endrule

	rule dac_feed_shiftreg(!dac_blocked[0] && dac_selected && prev_sCLK == 1'b1 && dut.dac_wires.sCLK == 1'b0);
		dac_shiftreg <= (dac_shiftreg << 1) | extend(dut.dac_wires.dIN);
	endrule

	(* descending_urgency = "dac_handle_cmd, dac_feed_shiftreg" *)
	rule dac_handle_cmd(dac_cmd matches tagged Valid .cmd);
		case(cmd) matches
			24'b00000101000000?000000000: $display("INFO: MAX5134 LIN reg set to %b", cmd[9]);
			24'b0001????????????????????:
				action
					DACMask   mask   = cmd[19:16];
					DACSample sample = cmd[15:0];
					for(Integer i = 0; i < valueOf(DACChans); i = i + 1)
						if(mask[i] == 1'b1)
							dac_regs[i] <= sample;
				endaction
			default:
				action
					$display("ERROR: Invalid MAX5134 command: %h", cmd);
					$finish(1);
				endaction
		endcase
		dac_shiftreg <= 25'b1;
		dac_blocked[0] <= True;
	endrule

	rule dac_handle_nLDAC(prev_nLDAC == 1'b1 && dut.dac_wires.nLDAC == 1'b0);
		for(Integer i = 0; i < valueOf(DACChans); i = i + 2)
			// "%u" writes little-endian in units of 32 bits
			$fwrite(dac_fh, "%u", byteSwap({dac_regs[i], dac_regs[i+1]}));
		$fflush(dac_fh);
	endrule

	rule bram_response_get;
		let data <- bram.portA.response.get;
		bram_pending_read.deq;
		data_out <= data;
	endrule

	rule bram_request_put;
		bram.portA.request.put(BRAMRequest{
			write: isWrite,
			responseOnWrite: False,
			address: dut.sram_wires.addr,
			datain: zdata
		});
		if(!isWrite)
			bram_pending_read.enq(?);
	endrule

	rule monitor_led_error_cond;
		// if NumInputs <= 7, then the 8th LED only lights up
		// on error condition
		if(dut.led_wires.led[7] == 1'b0) begin
			$display("ERROR: LEDs displayed an error condition");
			$finish(1);
		end
	endrule
endmodule
