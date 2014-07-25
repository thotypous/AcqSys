import Connectable::*;
import FIFOF::*;
import StmtFSM::*;
import PCIE::*; // for byteSwap
import Funnel::*;
import CycleCounter::*;
import GetPut::*;
export GetPut::*;

export JtagWord(..);
export AlteraJtagUart(..);
export mkAlteraJtagUart;

typedef 10 IntervalBetweenRX;
typedef  6 IntervalBetweenTX;

typedef Bit#(8) JtagWord;

interface AlteraJtagUart;
    interface Put#(JtagWord) tx;
    interface Get#(JtagWord) rx;
endinterface

module mkAlteraJtagUart#(Integer log2rx, Integer log2tx) (AlteraJtagUart);
    FIFOF#(JtagWord) rxfifo <- mkSizedFIFOF(2**log2rx);
    FIFOF#(JtagWord) txfifo <- mkSizedFIFOF(2**log2tx);
	
	CycleCounter#(IntervalBetweenRX) rxctr <- mkCycleCounter;
	CycleCounter#(IntervalBetweenTX) txctr <- mkCycleCounter;
	FIFOF#(void) rxticket <- mkFIFOF;
	FIFOF#(void) txticket <- mkFIFOF;

	rule rx_get_ticket(rxctr.ticked);
		rxticket.enq(?);
	endrule
	rule tx_get_ticket(txctr.ticked);
		txticket.enq(?);
	endrule

	// Unfunnel needed here because Verilog specifies $fwrite(fh, "%u", x)
	// writes in units of 32 bits.
	Funnel#(JtagWord, Bit#(32)) unfunnel <- mkUnfunnel;

	rule txfifo_to_unfunnel;
		txticket.deq;
		let data <- toGet(txfifo).get;
		unfunnel.in.put(data);
	endrule

	let jtagrx_fh <- mkReg(InvalidFile);
	let jtagtx_fh <- mkReg(InvalidFile);
	Once openFiles <- mkOnce(action
		let fh <- $fopen("dump.jtagrx", "rb");
		jtagrx_fh <= fh;
		fh <- $fopen("dump.jtagtx", "wb");
		jtagtx_fh <= fh;
	endaction);

	rule open_files;
		openFiles.start;
	endrule

	rule rx_read(jtagrx_fh != InvalidFile);
		rxticket.deq;
		let b <- $fgetc(jtagrx_fh);
		if(b < 0) begin
			$display("ERROR: EOF in JTAG RX before end of simulation");
			$finish(1);
		end
		rxfifo.enq(truncate(pack(b)));
	endrule

	rule tx_write;
		let data <- unfunnel.out.get;
		$fwrite(jtagtx_fh, "%u", byteSwap(data));
		$fflush(jtagtx_fh);
	endrule

    interface Put tx = toPut(txfifo);
    interface Get rx = toGet(rxfifo);
endmodule
