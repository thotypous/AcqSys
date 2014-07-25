import SRAM2CLK::*;
import SpecialFIFOs::*;
import FIFOF::*;
export FIFOF::*;

export SRAMFIFO(..);
export mkSRAMFIFO;

interface SRAMFIFO#(type addr_sz, type tdata);
	interface Client#(SRAMReq#(Bit#(addr_sz), tdata), tdata) cli;
	interface FIFOF#(tdata) fifo;
endinterface

module mkSRAMFIFO#(Bool turnRead, Bool turnWrite) (SRAMFIFO#(addr_sz, tdata))
provisos(
	Bits#(tdata, data_sz)
);
	Wire#(SRAMReq#(Bit#(addr_sz), tdata)) req_wire <- mkWire;
	FIFOF#(void) inflight <- mkFIFOF;
	Array#(Reg#(Bool)) inflight_notEmpty <- mkCRegU(3);
	Array#(Reg#(Bit#(addr_sz))) head <- mkCReg(3, 0);
	Array#(Reg#(Bit#(addr_sz))) tail <- mkCReg(3, 0);
	FIFOF#(tdata) odata <- mkLFIFOF;
	Array#(Reg#(Bool)) odata_notFull <- mkCRegU(3);
	Array#(Reg#(Bool)) ring_empty <- mkCReg(3, True);
	Array#(Reg#(Bool)) not_ring_full <- mkCReg(3, True);

	(* no_implicit_conditions, fire_when_enabled *)
	rule init_inflight_notEmpty;
		inflight_notEmpty[0] <= inflight.notEmpty;
	endrule

	(* no_implicit_conditions, fire_when_enabled *)
	rule init_odata_notFull;
		odata_notFull[0] <= odata.notFull;
	endrule

	interface Client cli;
		interface Get request;
			method ActionValue#(SRAMReq#(Bit#(addr_sz), tdata)) get;
				return req_wire;
			endmethod
		endinterface
		interface Put response;
			method Action put(tdata x) if (odata_notFull[1]);
				odata.enq(x);
				inflight.deq;
				odata_notFull[1] <= False;
			endmethod
		endinterface
	endinterface

	interface FIFOF fifo;
		method Action deq;
			odata.deq;
			(*split*)
			if(!ring_empty[0]) begin
				when(turnRead, action
					req_wire <= tagged Read head[0];
					inflight.enq(?);
					inflight_notEmpty[1] <= True;
					ring_empty[0] <= (head[0] + 1) == tail[0];
					not_ring_full[0] <= True;
					head[0] <= head[0] + 1;
				endaction);
			end
		endmethod
		method Action enq(tdata x) if (not_ring_full[1]);
			(*split*)
			if(odata_notFull[2] && !inflight_notEmpty[2] && ring_empty[1]) begin
				odata.enq(x);
			end else begin
				when(turnWrite, action
					req_wire <= Write{addr: tail[1], data: x};
					ring_empty[1] <= False;
					not_ring_full[1] <= head[1] != (tail[1] + 1);
					tail[1] <= tail[1] + 1;
				endaction);
			end
		endmethod
		method tdata first = odata.first;
		method Action clear if (!inflight.notEmpty);
			odata.clear;
			inflight.clear;
			head[2] <= 0;
			tail[2] <= 0;
			ring_empty[2] <= True;
			not_ring_full[2] <= True;
		endmethod
		method Bool notFull = not_ring_full[0];
		method Bool notEmpty = odata.notEmpty;
	endinterface
endmodule
