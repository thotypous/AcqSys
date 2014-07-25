#************************************************************
# THIS IS A WIZARD-GENERATED FILE.                           
#
# Version 13.0.1 Build 232 06/12/2013 Service Pack 1 SJ Full Version
#
#************************************************************

# Copyright (C) 1991-2013 Altera Corporation
# Your use of Altera Corporation's design tools, logic functions 
# and other software and tools, and its AMPP partner logic 
# functions, and any output files from any of the foregoing 
# (including device programming or simulation files), and any 
# associated documentation or information are expressly subject 
# to the terms and conditions of the Altera Program License 
# Subscription Agreement, Altera MegaCore Function License 
# Agreement, or other applicable license agreement, including, 
# without limitation, that your use is for the sole purpose of 
# programming logic devices manufactured by Altera and sold by 
# Altera or its authorized distributors.  Please refer to the 
# applicable agreement for further details.



# Clock constraints

create_clock -name "CLK" -period 20.000ns [get_ports {CLK}]


# Automatically constrain PLL and other generated clocks
derive_pll_clocks -create_base_clocks

# Automatically calculate clock uncertainty to jitter and other effects.
#derive_clock_uncertainty
# Not supported for family MAX II

# tsu/th constraints

set_input_delay -clock "CLK" -max 12ns [get_ports {SRAM_DATA[*]}] 
set_input_delay -clock "CLK" -min 3.000ns [get_ports {SRAM_DATA[*]}] 
set_input_delay -clock "CLK" -max 0ns [get_ports {RST_N}] 
set_input_delay -clock "CLK" -min 20ns [get_ports {RST_N}] 


# tco constraints

set_output_delay -clock "CLK" -max 12ns [get_ports {SRAM_ADDR[*]}] 
set_output_delay -clock "CLK" -min -0.000ns [get_ports {SRAM_ADDR[*]}] 
set_output_delay -clock "CLK" -max 12ns [get_ports {SRAM_DATA[*]}] 
set_output_delay -clock "CLK" -min -0.000ns [get_ports {SRAM_DATA[*]}] 
set_output_delay -clock "CLK" -max 12ns [get_ports {SRAM_NWE}] 
set_output_delay -clock "CLK" -min -0.000ns [get_ports {SRAM_NWE}] 

set_output_delay -clock "CLK" -max 12ns [get_ports {DAC_NLDAC}]
set_output_delay -clock "CLK" -min -0.000ns [get_ports {DAC_NLDAC}]
set_output_delay -clock "CLK" -max 12ns [get_ports {DAC_SCLK}]
set_output_delay -clock "CLK" -min -0.000ns [get_ports {DAC_SCLK}]
set_output_delay -clock "CLK" -max 12ns [get_ports {DAC_NCS}]
set_output_delay -clock "CLK" -min -0.000ns [get_ports {DAC_NCS}]
set_output_delay -clock "CLK" -max 12ns [get_ports {DAC_DIN}]
set_output_delay -clock "CLK" -min -0.000ns [get_ports {DAC_DIN}]

# tpd constraints

