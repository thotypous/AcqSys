import GetPut::*;
import FIFOF::*;
export GetPut::*;

export Funnel(..);
export mkFunnel;
export mkUnfunnel;

interface Funnel#(type a, type b);
	interface Put#(a) in;
	interface Get#(b) out;
	method Bool notFull;
endinterface

function Funnel#(a,b) toFunnel(FIFOF#(a) infifo, FIFOF#(b) outfifo);
	return (interface Funnel;
		interface Put in = toPut(infifo);
		interface Get out = toGet(outfifo);
		method Bool notFull = infifo.notFull;
	endinterface);
endfunction

module mkFunnel(Funnel#(a,b))
provisos(
	Bits#(a,na), Bits#(b,nb),
	Mul#(nb,nparts,na),
	// not obvious for the compiler yet?
	Add#(a__, nb, na),
	Add#(nb, b__, TSub#(na, nb))
);
	FIFOF#(a) infifo <- mkLFIFOF;
	FIFOF#(b) outfifo <- mkLFIFOF;
	Reg#(Bit#(TSub#(na,nb))) shiftReg <- mkRegU;
	Reg#(UInt#(TLog#(nparts))) stage <- mkReg(0);
	
	let nParts = valueOf(nparts);
	let nB = valueOf(nb);

	rule firstCycle(stage == 0);
		let inval = pack(infifo.first);
		shiftReg <= truncateLSB(inval << nB);
		infifo.deq;
		outfifo.enq(unpack(truncateLSB(inval)));
		stage <= stage + 1;
	endrule

	rule cycle(stage != 0);
		outfifo.enq(unpack(truncateLSB(shiftReg)));
		shiftReg <= shiftReg << nB;
		stage <= stage == fromInteger(nParts - 1) ? 0 : stage + 1;
	endrule

	return toFunnel(infifo, outfifo);
endmodule

module mkUnfunnel(Funnel#(a,b))
provisos(
	Bits#(a,na), Bits#(b,nb),
	Mul#(na,nparts,nb),
	// not obvious for the compiler yet?
	Add#(a__, na, TSub#(nb, na))
);
	FIFOF#(a) infifo <- mkLFIFOF;
	FIFOF#(b) outfifo <- mkLFIFOF;
	Reg#(Bit#(TSub#(nb,na))) shiftReg <- mkRegU;
	Reg#(UInt#(TLog#(nparts))) stage <- mkReg(0);

	let nParts = valueOf(nparts);
	let nA = valueOf(na);
	UInt#(TLog#(nparts)) lastStage = fromInteger(nParts - 1);

	let inval = pack(infifo.first);

	rule lastCycle(stage == lastStage);
		infifo.deq;
		outfifo.enq(unpack({shiftReg, inval}));
		stage <= 0;
	endrule

	rule cycle(stage != lastStage);
		infifo.deq;
		shiftReg <= (stage == 0) ?
			zeroExtend(inval) :
			(shiftReg << nA) | zeroExtend(inval);
		stage <= stage + 1;
	endrule

	return toFunnel(infifo, outfifo);
endmodule
