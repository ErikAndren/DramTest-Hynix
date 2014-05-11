-- megafunction wizard: %FIFO%
-- GENERATION: STANDARD
-- VERSION: WM1.0
-- MODULE: dcfifo 

-- ============================================================
-- File Name: ReqFifo.vhd
-- Megafunction Name(s):
-- 			dcfifo
--
-- Simulation Library Files(s):
-- 			altera_mf
-- ============================================================
-- ************************************************************
-- THIS IS A WIZARD-GENERATED FILE. DO NOT EDIT THIS FILE!
--
-- 13.0.1 Build 232 06/12/2013 SP 1 SJ Web Edition
-- ************************************************************


--Copyright (C) 1991-2013 Altera Corporation
--Your use of Altera Corporation's design tools, logic functions 
--and other software and tools, and its AMPP partner logic 
--functions, and any output files from any of the foregoing 
--(including device programming or simulation files), and any 
--associated documentation or information are expressly subject 
--to the terms and conditions of the Altera Program License 
--Subscription Agreement, Altera MegaCore Function License 
--Agreement, or other applicable license agreement, including, 
--without limitation, that your use is for the sole purpose of 
--programming logic devices manufactured by Altera and sold by 
--Altera or its authorized distributors.  Please refer to the 
--applicable agreement for further details.


LIBRARY ieee;
USE ieee.std_logic_1164.all;

LIBRARY altera_mf;
USE altera_mf.all;

ENTITY ReqFifo IS
	PORT
	(
		data		: IN STD_LOGIC_VECTOR (155 DOWNTO 0);
		rdclk		: IN STD_LOGIC ;
		rdreq		: IN STD_LOGIC ;
		wrclk		: IN STD_LOGIC ;
		wrreq		: IN STD_LOGIC ;
		q		: OUT STD_LOGIC_VECTOR (155 DOWNTO 0);
		rdempty		: OUT STD_LOGIC ;
		wrfull		: OUT STD_LOGIC 
	);
END ReqFifo;


ARCHITECTURE SYN OF reqfifo IS

	SIGNAL sub_wire0	: STD_LOGIC ;
	SIGNAL sub_wire1	: STD_LOGIC_VECTOR (155 DOWNTO 0);
	SIGNAL sub_wire2	: STD_LOGIC ;



	COMPONENT dcfifo
	GENERIC (
		intended_device_family		: STRING;
		lpm_numwords		: NATURAL;
		lpm_showahead		: STRING;
		lpm_type		: STRING;
		lpm_width		: NATURAL;
		lpm_widthu		: NATURAL;
		overflow_checking		: STRING;
		rdsync_delaypipe		: NATURAL;
		underflow_checking		: STRING;
		use_eab		: STRING;
		wrsync_delaypipe		: NATURAL
	);
	PORT (
			data	: IN STD_LOGIC_VECTOR (155 DOWNTO 0);
			rdclk	: IN STD_LOGIC ;
			rdreq	: IN STD_LOGIC ;
			wrfull	: OUT STD_LOGIC ;
			q	: OUT STD_LOGIC_VECTOR (155 DOWNTO 0);
			rdempty	: OUT STD_LOGIC ;
			wrclk	: IN STD_LOGIC ;
			wrreq	: IN STD_LOGIC 
	);
	END COMPONENT;

BEGIN
	wrfull    <= sub_wire0;
	q    <= sub_wire1(155 DOWNTO 0);
	rdempty    <= sub_wire2;

	dcfifo_component : dcfifo
	GENERIC MAP (
		intended_device_family => "Cyclone II",
		lpm_numwords => 32,
		lpm_showahead => "OFF",
		lpm_type => "dcfifo",
		lpm_width => 156,
		lpm_widthu => 5,
		overflow_checking => "OFF",
		rdsync_delaypipe => 4,
		underflow_checking => "OFF",
		use_eab => "ON",
		wrsync_delaypipe => 4
	)
	PORT MAP (
		data => data,
		rdclk => rdclk,
		rdreq => rdreq,
		wrclk => wrclk,
		wrreq => wrreq,
		wrfull => sub_wire0,
		q => sub_wire1,
		rdempty => sub_wire2
	);



END SYN;

-- ============================================================
-- CNX file retrieval info
-- ============================================================
-- Retrieval info: PRIVATE: AlmostEmpty NUMERIC "0"
-- Retrieval info: PRIVATE: AlmostEmptyThr NUMERIC "-1"
-- Retrieval info: PRIVATE: AlmostFull NUMERIC "0"
-- Retrieval info: PRIVATE: AlmostFullThr NUMERIC "-1"
-- Retrieval info: PRIVATE: CLOCKS_ARE_SYNCHRONIZED NUMERIC "0"
-- Retrieval info: PRIVATE: Clock NUMERIC "4"
-- Retrieval info: PRIVATE: Depth NUMERIC "32"
-- Retrieval info: PRIVATE: Empty NUMERIC "1"
-- Retrieval info: PRIVATE: Full NUMERIC "1"
-- Retrieval info: PRIVATE: INTENDED_DEVICE_FAMILY STRING "Cyclone II"
-- Retrieval info: PRIVATE: LE_BasedFIFO NUMERIC "0"
-- Retrieval info: PRIVATE: LegacyRREQ NUMERIC "1"
-- Retrieval info: PRIVATE: MAX_DEPTH_BY_9 NUMERIC "0"
-- Retrieval info: PRIVATE: OVERFLOW_CHECKING NUMERIC "1"
-- Retrieval info: PRIVATE: Optimize NUMERIC "0"
-- Retrieval info: PRIVATE: RAM_BLOCK_TYPE NUMERIC "0"
-- Retrieval info: PRIVATE: SYNTH_WRAPPER_GEN_POSTFIX STRING "0"
-- Retrieval info: PRIVATE: UNDERFLOW_CHECKING NUMERIC "1"
-- Retrieval info: PRIVATE: UsedW NUMERIC "1"
-- Retrieval info: PRIVATE: Width NUMERIC "156"
-- Retrieval info: PRIVATE: dc_aclr NUMERIC "0"
-- Retrieval info: PRIVATE: diff_widths NUMERIC "0"
-- Retrieval info: PRIVATE: msb_usedw NUMERIC "0"
-- Retrieval info: PRIVATE: output_width NUMERIC "156"
-- Retrieval info: PRIVATE: rsEmpty NUMERIC "1"
-- Retrieval info: PRIVATE: rsFull NUMERIC "0"
-- Retrieval info: PRIVATE: rsUsedW NUMERIC "0"
-- Retrieval info: PRIVATE: sc_aclr NUMERIC "0"
-- Retrieval info: PRIVATE: sc_sclr NUMERIC "0"
-- Retrieval info: PRIVATE: wsEmpty NUMERIC "0"
-- Retrieval info: PRIVATE: wsFull NUMERIC "1"
-- Retrieval info: PRIVATE: wsUsedW NUMERIC "0"
-- Retrieval info: LIBRARY: altera_mf altera_mf.altera_mf_components.all
-- Retrieval info: CONSTANT: INTENDED_DEVICE_FAMILY STRING "Cyclone II"
-- Retrieval info: CONSTANT: LPM_NUMWORDS NUMERIC "32"
-- Retrieval info: CONSTANT: LPM_SHOWAHEAD STRING "OFF"
-- Retrieval info: CONSTANT: LPM_TYPE STRING "dcfifo"
-- Retrieval info: CONSTANT: LPM_WIDTH NUMERIC "156"
-- Retrieval info: CONSTANT: LPM_WIDTHU NUMERIC "5"
-- Retrieval info: CONSTANT: OVERFLOW_CHECKING STRING "OFF"
-- Retrieval info: CONSTANT: RDSYNC_DELAYPIPE NUMERIC "4"
-- Retrieval info: CONSTANT: UNDERFLOW_CHECKING STRING "OFF"
-- Retrieval info: CONSTANT: USE_EAB STRING "ON"
-- Retrieval info: CONSTANT: WRSYNC_DELAYPIPE NUMERIC "4"
-- Retrieval info: USED_PORT: data 0 0 156 0 INPUT NODEFVAL "data[155..0]"
-- Retrieval info: USED_PORT: q 0 0 156 0 OUTPUT NODEFVAL "q[155..0]"
-- Retrieval info: USED_PORT: rdclk 0 0 0 0 INPUT NODEFVAL "rdclk"
-- Retrieval info: USED_PORT: rdempty 0 0 0 0 OUTPUT NODEFVAL "rdempty"
-- Retrieval info: USED_PORT: rdreq 0 0 0 0 INPUT NODEFVAL "rdreq"
-- Retrieval info: USED_PORT: wrclk 0 0 0 0 INPUT NODEFVAL "wrclk"
-- Retrieval info: USED_PORT: wrfull 0 0 0 0 OUTPUT NODEFVAL "wrfull"
-- Retrieval info: USED_PORT: wrreq 0 0 0 0 INPUT NODEFVAL "wrreq"
-- Retrieval info: CONNECT: @data 0 0 156 0 data 0 0 156 0
-- Retrieval info: CONNECT: @rdclk 0 0 0 0 rdclk 0 0 0 0
-- Retrieval info: CONNECT: @rdreq 0 0 0 0 rdreq 0 0 0 0
-- Retrieval info: CONNECT: @wrclk 0 0 0 0 wrclk 0 0 0 0
-- Retrieval info: CONNECT: @wrreq 0 0 0 0 wrreq 0 0 0 0
-- Retrieval info: CONNECT: q 0 0 156 0 @q 0 0 156 0
-- Retrieval info: CONNECT: rdempty 0 0 0 0 @rdempty 0 0 0 0
-- Retrieval info: CONNECT: wrfull 0 0 0 0 @wrfull 0 0 0 0
-- Retrieval info: GEN_FILE: TYPE_NORMAL ReqFifo.vhd TRUE
-- Retrieval info: GEN_FILE: TYPE_NORMAL ReqFifo.inc FALSE
-- Retrieval info: GEN_FILE: TYPE_NORMAL ReqFifo.cmp TRUE
-- Retrieval info: GEN_FILE: TYPE_NORMAL ReqFifo.bsf FALSE
-- Retrieval info: GEN_FILE: TYPE_NORMAL ReqFifo_inst.vhd FALSE
-- Retrieval info: LIB_FILE: altera_mf
