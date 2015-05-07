include ../../config.mk

VERILOG_FILES=mkAcqSys.v ../common/AsyncPulseSync.v
QSF_FILE=mkAcqSys.qsf
PROJECT_FILES=mkAcqSys.qpf mkAcqSys.sdc $(QSF_FILE)
QUARTUS_BUILD_DIR=build

pof: $(QUARTUS_BUILD_DIR)/output_files/mkAcqSys.pof

$(QUARTUS_BUILD_DIR)/output_files/mkAcqSys.pof: $(VERILOG_FILES)
	mkdir -p $(QUARTUS_BUILD_DIR)
	cp $(VERILOG_FILES) $(addprefix ../common/, $(PROJECT_FILES)) $(QUARTUS_BUILD_DIR)
	sed -i 's,$${BLUESPECHOME},$(BLUESPECHOME),g' $(QUARTUS_BUILD_DIR)/$(QSF_FILE)
	cd $(QUARTUS_BUILD_DIR); $(QUARTUS_ROOTDIR)/bin/quartus_sh --flow compile mkAcqSys
