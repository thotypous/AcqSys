interface CentralArbiter#(numeric type arbitrated_units);
	interface ReadOnly#(Bit#(TLog#(arbitrated_units))) turn;
endinterface

module mkCentralArbiter(CentralArbiter#(n));
	Reg#(Bit#(TLog#(n))) turnCounter <- mkRegU;
	rule incrementTurn;
		let maxCount = fromInteger(valueOf(n) - 1);
		turnCounter <= (turnCounter == maxCount) ? 0 : (turnCounter + 1);
	endrule
	interface ReadOnly turn = regToReadOnly(turnCounter);
endmodule
