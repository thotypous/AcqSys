import SRAM2CLK::*;
import SpecialFIFOs::*;
import FIFOF::*;
export FIFOF::*;

export SRAMFIFO(..);
export mkSRAMFIFO;

typedef enum {
	Read,
	Write,
	ReadThenWrite,
	WriteThenRead
} Turn deriving(Bits, Eq);

typedef enum {
	Read,
	Write
} MemOp deriving(Bits, Eq);

interface SRAMFIFO#(type addr_sz, type tdata);
	interface Client#(SRAMReq#(Bit#(addr_sz), tdata), tdata) cli;
	interface FIFOF#(tdata) fifo;
endinterface

module mkSRAMFIFO(SRAMFIFO#(addr_sz, tdata))
provisos(
	Bits#(tdata, data_sz)
);
	FIFOF#(Tuple2#(Bit#(addr_sz), tdata)) req_write <- mkBypassFIFOF;
	FIFOF#(Bit#(addr_sz)) req_read <- mkBypassFIFOF;
	FIFOF#(void) inflight <- mkFIFOF;
	Array#(Reg#(Bool)) inflight_notEmpty <- mkCRegU(3);
	Array#(Reg#(Bit#(addr_sz))) head <- mkCReg(3, 0);
	Array#(Reg#(Bit#(addr_sz))) tail <- mkCReg(3, 0);
	FIFOF#(tdata) odata <- mkLFIFOF;
	Array#(Reg#(Bool)) odata_notFull <- mkCRegU(3);
	Array#(Reg#(Bool)) ring_empty <- mkCReg(3, True);
	Array#(Reg#(Bool)) not_ring_full <- mkCReg(3, True);

	PulseWire deq_requested_mem <- mkPulseWire;
	PulseWire enq_requested_mem <- mkPulseWire;
	FIFOF#(Turn) req_turn <- mkBypassFIFOF;
	Array#(Reg#(Bool)) req_turn_notFull <- mkCRegU(3);
	Array#(Reg#(MemOp)) last_op <- mkCRegU(2);
	Reg#(Bit#(1)) turn_stage <- mkReg(0);

	(* no_implicit_conditions, fire_when_enabled *)
	rule init_inflight_notEmpty;
		inflight_notEmpty[0] <= inflight.notEmpty;
	endrule

	(* no_implicit_conditions, fire_when_enabled *)
	rule init_odata_notFull;
		odata_notFull[0] <= odata.notFull;
	endrule

	function Action compute_req_turn_notify(PulseWire pwire);
		return when(req_turn.notFull, pwire.send);
	endfunction

	rule compute_req_turn(deq_requested_mem || enq_requested_mem);
		if(deq_requested_mem && enq_requested_mem) begin
			if(head[2] == tail[2]) begin
				// conflict: deq has read from head[2]-1 and enq has written to tail[2]-1
				// enforce memory order compatible with method order:
				// deq < enq implies read < write
				req_turn.enq(ReadThenWrite);
			end else begin
				req_turn.enq(last_op[0] == Read ? WriteThenRead : ReadThenWrite);
			end
		end else if(deq_requested_mem && !enq_requested_mem) begin
			req_turn.enq(Read);
		end else if(!deq_requested_mem && enq_requested_mem) begin
			req_turn.enq(Write);
		end
	endrule

	interface Client cli;
		interface Get request;
			method ActionValue#(SRAMReq#(Bit#(addr_sz), tdata)) get;
				MemOp turn = ?;
				case (req_turn.first) matches
					Read:  action turn = Read;  req_turn.deq; endaction
					Write: action turn = Write; req_turn.deq; endaction
					ReadThenWrite:
						action
							turn = turn_stage == 1'b0 ? Read : Write;
							if(turn_stage == 1'b1) req_turn.deq;
							turn_stage <= ~turn_stage;
						endaction
					WriteThenRead:
						action
							turn = turn_stage == 1'b0 ? Write: Read;
							if(turn_stage == 1'b1) req_turn.deq;
							turn_stage <= ~turn_stage;
						endaction
				endcase
				last_op[1] <= turn;
				(*split*)
				if(turn == Read) begin
					req_read.deq;
					return tagged Read req_read.first;
				end else begin
					let {addr, data} = req_write.first;
					req_write.deq;
					return Write{addr:addr, data:data};
				end
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
				req_read.enq(head[0]);
				compute_req_turn_notify(deq_requested_mem);
				inflight.enq(?);
				inflight_notEmpty[1] <= True;
				ring_empty[0] <= (head[0] + 1) == tail[0];
				not_ring_full[0] <= True;
				head[0] <= head[0] + 1;
			end
		endmethod
		method Action enq(tdata x) if (not_ring_full[1]);
			(*split*)
			if(odata_notFull[2] && !inflight_notEmpty[2] && ring_empty[1]) begin
				odata.enq(x);
			end else begin
				req_write.enq(tuple2(tail[1], x));
				compute_req_turn_notify(enq_requested_mem);
				ring_empty[1] <= False;
				not_ring_full[1] <= head[1] != (tail[1] + 1);
				tail[1] <= tail[1] + 1;
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
