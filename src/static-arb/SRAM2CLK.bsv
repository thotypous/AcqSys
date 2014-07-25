import GetPut::*;
export GetPut::*;
import ClientServer::*;
export ClientServer::*;
import TriState::*;
import FIFOF::*;
import Counter::*;

export SRAMWires(..);
export SRAMReq(..);
export SRAM(..);
export mkSRAM;

interface SRAMWires#(type taddr, type tdata);
	(* result = "ADDR", always_ready *)
	method taddr addr;
	(* prefix = "DATA", always_ready *)
	interface Inout#(tdata) data;
	(* result = "NWE" , always_ready *)
	method Bit#(1) nwe;
endinterface 

interface SRAM#(type taddr, type tdata);
	(* prefix = "" *)
	interface SRAMWires#(taddr, tdata) wires;
	interface Server#(SRAMReq#(taddr, tdata), tdata) ifc;
endinterface

// External request representation (easier to write in BSV code).
typedef union tagged {
	taddr Read;
	struct {
		tdata data;
		taddr addr;
	} Write;
} SRAMReq#(type taddr, type tdata) deriving(Eq, Bits);

module mkSRAM#(Bit#(1) turn) (SRAM#(taddr, tdata))
provisos(
	Bits#(taddr, addr_sz),
	Bits#(tdata, data_sz)
);
	Wire#(taddr) addr_wire <- mkDWire(?);
	Wire#(Maybe#(tdata)) dataout <- mkDWire(tagged Invalid);
	Wire#(Bit#(1)) nwe_wire <- mkDWire(1);
	TriState#(tdata) zbuf <- mkTriState(isValid(dataout), fromMaybe(?, dataout));

	FIFOF#(SRAMReq#(taddr, tdata)) reqfifo <- mkLFIFOF;
	FIFOF#(tdata) respfifo <- mkLFIFOF;

	rule fifo_to_wires;
		case(reqfifo.first) matches
			tagged Write .s:
			action
				addr_wire <= s.addr;
				dataout <= tagged Valid s.data;
				if(turn == 1)
					nwe_wire <= 0;
			endaction
			tagged Read .a: addr_wire <= a;
		endcase
	endrule

	rule cycle_machine(turn == 0);
		reqfifo.deq;
		(*split*)
		if(reqfifo.first matches tagged Read .a)
			respfifo.enq(zbuf);
	endrule

	interface SRAMWires wires;
		method taddr addr = addr_wire;
		interface Inout data = zbuf.io;
		method Bit#(1) nwe = nwe_wire;
	endinterface

	interface Server ifc;
		interface Put request;
			method Action put(SRAMReq#(taddr, tdata) req) if (turn == 0);
				reqfifo.enq(req);
			endmethod
		endinterface
		interface Get response = toGet(respfifo);
	endinterface
endmodule
