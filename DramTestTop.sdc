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

create_generated_clock -name Clk100MHz -source [get_pins {Pll100MHz|altpll_component|pll|inclk[0]}] -duty_cycle 50.000 -multiply_by 2 -master_clock {Clk} [get_pins {Pll100MHz|altpll_component|pll|clk[0]}] 

# Divided clocks
create_generated_clock -name Clk50Mhz -source [get_nets {Pll100MHz|altpll_component|_clk0}] -divide_by 2 [get_pins {ClkDivTo50Mhz|divisor|regout}]
create_generated_clock -name Clk25MHz -source [get_pins {ClkDivTo50Mhz|divisor|regout}] -divide_by 2 [get_pins {ClkDivTo25Mhz|divisor|regout}]

#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************



#**************************************************************
# Set Input Delay
#**************************************************************



#**************************************************************
# Set Output Delay
#**************************************************************



#**************************************************************
# Set Clock Groups
#**************************************************************



#**************************************************************
# Set False Path
#**************************************************************



#**************************************************************
# Set Multicycle Path
#**************************************************************



#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************

