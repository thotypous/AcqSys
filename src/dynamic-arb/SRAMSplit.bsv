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

module mkSRAMSplit(SRAMSplit#(addr_sz, tdata))
provisos(
	Bits#(tdata, data_sz),
	Bits#(SRAMReq#(Bit#(TSub#(addr_sz, 1)), tdata), inreq_sz)
);
	Vector#(2, FIFOF#(SRAMReq#(Bit#(TSub#(addr_sz,1)), tdata))) reqfifo <- replicateM(mkLFIFOF);
	SRAM#(Bit#(addr_sz), tdata) sram <- mkSRAM;
	FIFOF#(Bit#(1)) pending <- mkLFIFOF;
	Reg#(Bit#(1)) turn <- mkRegU;

	function prefixReq(p, req);
		case(req) matches
			tagged Write .s: return Write{addr:{p,s.addr}, data:s.data};
			tagged Read  .a: return tagged Read ({p,a});
		endcase
	endfunction

	function getPriorizeValid(p);
		return (rules
			rule priorize_valid(reqfifo[p].notEmpty && !reqfifo[~p].notEmpty);
				let req <- toGet(reqfifo[p]).get;
				sram.ifc.request.put(prefixReq(p, req));
				turn <= ~p;
				(*nosplit*)
				if(req matches tagged Read .a)
					pending.enq(p);
			endrule
		endrules);
	endfunction

	rule priorize_current_turn(reqfifo[0].notEmpty && reqfifo[1].notEmpty);
		let req <- toGet(reqfifo[turn]).get;
		sram.ifc.request.put(prefixReq(turn, req));
		turn <= ~turn;
		(*nosplit*)
		if(req matches tagged Read .a)
			pending.enq(turn);
	endrule

	addRules(getPriorizeValid(0));
	addRules(getPriorizeValid(1));

	function srvIfc(p);
		return (interface Server;
			interface Put request = toPut(reqfifo[p]);
			interface Get response;
				method ActionValue#(tdata) get if (pending.first==p);
					let data <- sram.ifc.response.get;
					pending.deq;
					return data; 
				endmethod
			endinterface
		endinterface);
	endfunction

	interface SRAMWires wires = sram.wires;
	interface Server srvA = srvIfc(0);
	interface Server srvB = srvIfc(1);
endmodule
