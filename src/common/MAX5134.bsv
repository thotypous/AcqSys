import StmtFSM::*;
import GetPut::*;
import SysConfig::*;

export GetPut::*;
export DACChans(..);
export DACMask(..);
export DACSample(..);
export DACReq(..);
export DACWires(..);
export DAC(..);
export mkDAC;

typedef 4 DACChans;
typedef Bit#(DACChans) DACMask;
typedef Bit#(16) DACSample;

typedef Tuple2#(DACMask, DACSample) DACReq;

interface DACWires;
	(* result="NLDAC", always_ready *)
	method Bit#(1) nLDAC;
	(* result="SCLK", always_ready *)
	method Bit#(1) sCLK;
	(* result="NCS", always_ready *)
	method Bit#(1) nCS;
	(* result="DIN", always_ready *)
	method Bit#(1) dIN;
endinterface

interface DAC;
	interface Put#(DACReq) req;
	method Bool isReady;
	method Action load;
	interface DACWires wires;
endinterface

module mkDAC(DAC);
	Reg#(Bit#(1)) rnLDAC <- mkReg(1);
	Reg#(Bit#(1)) rsCLK  <- mkReg(1);
	Array#(Reg#(Bit#(1))) rnCS <- mkCReg(2, 1);
	Reg#(Bit#(1)) rdIN   <- mkRegU;

	Reg#(Bit#(25)) shiftReg <- mkRegU;
	Bool shiftRegDone = shiftReg == (1<<24);

	Stmt shiftRegSenderStmt = seq
		while(!shiftRegDone) seq
			action
				rsCLK <= 1;
				rdIN <= shiftReg[24];
			endaction
			action
				rsCLK <= 0;
				shiftReg <= shiftReg << 1;
			endaction
		endseq
		rnCS[0] <= 1;
		delay(2);
	endseq;
	FSM shiftRegSender <- mkFSM(shiftRegSenderStmt);

	function Action send(Bit#(24) cmd);
		action
			shiftReg <= {cmd, 1'b1};
			rnCS[1] <= 0;
			shiftRegSender.start;
		endaction
	endfunction

	Stmt pulseLDACStmt = seq
		rnLDAC <= 0;
		noAction;
		rnLDAC <= 1;
	endseq;
	FSM pulseLDAC <- mkFSM(pulseLDACStmt);

	Stmt dacCalibrationStmt = seq
		delay(dacCalibCycles);
		send(24'b000001010000001000000000);
		shiftRegSender.waitTillDone;
		delay(dacCalibCycles);
		send(24'b000001010000000000000000);
	endseq;
	FSM dacCalibration <- mkFSM(dacCalibrationStmt);
	Once dacCalibrationOnce <- mkOnce(dacCalibration.start);
	rule startCalibration;
		dacCalibrationOnce.start;
	endrule

	Bool rdy = dacCalibration.done && shiftRegSender.done && pulseLDAC.done;
	method Bool isReady = rdy;

	interface Put req;
		method Action put(DACReq r) if (rdy);
			match {.mask, .sample} = r;
			send({4'b0001, mask, sample});
		endmethod
	endinterface

	method Action load if (rdy) = pulseLDAC.start;

	interface DACWires wires;
		method Bit#(1) nLDAC = rnLDAC;
		method Bit#(1) sCLK = rsCLK;
		method Bit#(1) nCS = rnCS[0];
		method Bit#(1) dIN = rdIN;
	endinterface
endmodule
