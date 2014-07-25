import SRAM2CLK::*;
export SRAM2CLK::*;
import SpecialFIFOs::*;
import FIFOF::*;
import Vector::*;

export SRAMSplit(..);
export mkSRAMSplit;

interface SRAMSplit#(type addr_sz, type tdata);
	(* prefix = "" *)
	interface SRAMWires#(Bit#(addr_sz), tdata) wires;
	interface Server#(SRAMReq#(Bit#(TSub#(addr_sz,1)), tdata), tdata) srvA;
	interface Server#(SRAMReq#(Bit#(TSub#(addr_sz,1)), tdata), tdata) srvB;
endinterface

module mkSRAMSplit#(Bit#(1) srvTurn, Bit#(1) sramTurn, Bool respCondA, Bool respCondB) (SRAMSplit#(addr_sz, tdata))
provisos(
	Bits#(tdata, data_sz),
	Bits#(SRAMReq#(Bit#(TSub#(addr_sz, 1)), tdata), inreq_sz)
);
	SRAM#(Bit#(addr_sz), tdata) sram <- mkSRAM(sramTurn);

	function prefixReq(p, req);
		case(req) matches
			tagged Write .s: return Write{addr:{p,s.addr}, data:s.data};
			tagged Read  .a: return tagged Read ({p,a});
		endcase
	endfunction

	function srvIfc(p);
		Bool getCond = (p == 0) ? respCondA : respCondB;
		return (interface Server;
			interface Put request;
				method Action put(SRAMReq#(Bit#(TSub#(addr_sz,1)), tdata) req) if (srvTurn == p);
					sram.ifc.request.put(prefixReq(p, req));
				endmethod
			endinterface
			interface Get response;
				method ActionValue#(tdata) get if (getCond);
					let data <- sram.ifc.response.get;
					return data; 
				endmethod
			endinterface
		endinterface);
	endfunction

	interface SRAMWires wires = sram.wires;
	interface Server srvA = srvIfc(0);
	interface Server srvB = srvIfc(1);
endmodule
