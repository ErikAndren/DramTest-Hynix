## Generated SDC file "DramTestTop.sdc"

## Copyright (C) 1991-2013 Altera Corporation
## Your use of Altera Corporation's design tools, logic functions 
## and other software and tools, and its AMPP partner logic 
## functions, and any output files from any of the foregoing 
## (including device programming or simulation files), and any 
## associated documentation or information are expressly subject 
## to the terms and conditions of the Altera Program License 
## Subscription Agreement, Altera MegaCore Function License 
## Agreement, or other applicable license agreement, including, 
## without limitation, that your use is for the sole purpose of 
## programming logic devices manufactured by Altera and sold by 
## Altera or its authorized distributors.  Please refer to the 
## applicable agreement for further details.


## VENDOR  "Altera"
## PROGRAM "Quartus II"
## VERSION "Version 13.0.1 Build 232 06/12/2013 Service Pack 1 SJ Web Edition"

## DATE    "Thu Apr 17 20:37:34 2014"

##
## DEVICE  "EP2C8Q208C8"
##

set board_delay 1.000

# Sdram timing constants
set sdram_clk_period 10.000

# sdram input hold tHO
set sdram_tH 0.800

set sdram_tOH 2.000

set sdram_tOLZ 1.000

set sdram_tOHZ 5.400

set sdram_tDH 0.800

set sdram_tDS 1.500

set sdram_data_input_delay_max [expr $board_delay + $sdram_tOHZ]
set sdram_data_input_delay_min [expr $board_delay + $sdram_tOH]

set sdram_output_delay_max [expr $board_delay + $sdram_tDS]
set sdram_output_delay_min [expr $board_delay + $sdram_tDH]

#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3

#**************************************************************
# Create Clock
#**************************************************************

create_clock -name {Clk} -period 20.000 -waveform { 0.000 10.000 } [get_ports {Clk}]

#**************************************************************
# Create Generated Clock
#**************************************************************

derive_pll_clocks -create_base_clocks

create_generated_clock -name SdramClk_pin -source [get_pins {Pll100MHz|altpll_component|pll|clk[1]}] [get_ports {ClkToSdram}]

create_generated_clock -name Clk64kHz -source [get_pins {Pll100MHz|altpll_component|pll|clk[2]}] -divide_by 16000 [get_registers {ClkDiv:Clk64kHzGen|divisor}]

derive_clock_uncertainty

# Constrain I/O ports
set_input_delay -clock SdramClk_pin -source -max $sdram_data_input_delay_max [get_ports SdramDQ\[*\]]
set_input_delay -clock SdramClk_pin -source -min $sdram_data_input_delay_min [get_ports SdramDQ\[*\]]

set_output_delay -clock SdramClk_pin -source -max $sdram_output_delay_max [get_ports Sdram*]
set_output_delay -clock SdramClk_pin -source -min -${sdram_output_delay_min} [get_ports Sdram*]

#set_multicycle_path -from [get_clocks SdramClk_pin] -to [get_clocks {Pll100MHz|altpll_component|pll|clk[0]}] -setup -end 2
#set_multicycle_path -from [get_clocks SdramClk_pin] -to [get_clocks {Pll100MHz|altpll_component|pll|clk[0]}] -hold -end 2
#set_multicycle_path -from {Pll100MHz|altpll_component|pll|clk[1]} -to {SdramClk} -setup -end 2
#set_multicycle_path -from {Pll100MHz|altpll_component|pll|clk[1]} -to {SdramClk} -hold -end 2 

#**************************************************************
# Set Input Transition
#**************************************************************

