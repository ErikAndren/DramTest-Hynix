FILES=source/DramTestPack.vhd \
	ReqFifo.vhd \
	RespFIFO.vhd \
	PLL.vhd \
	source/VGAGenerator.vhd \
	source/FakeVgaCam.vhd \
	source/CamAligner.vhd \
	source/SdramArbiter.vhd \
	source/RequestHandler.vhd \
	source/RespHandler.vhd \
	source/Command.vhd \
	source/control_interface.vhd \
	source/RequestHandler.vhd \
	source/sdr_data_path.vhd \
	source/sdr_sdram.vhd \
	source/DramTestTop.vhd \
	source/tb.vhd


WORK_DIR="/tmp/work"
MODELSIMINI_PATH=/home/erik/Development/FPGA/OV76X0/modelsim.ini

QUARTUS_PATH=/opt/altera/13.0sp1/quartus

CC=vcom
FLAGS=-work $(WORK_DIR) -93 -modelsimini $(MODELSIMINI_PATH)
VMAP=vmap
VLIB=vlib
VSIM=vsim
TBTOP=tb

TB_TASK_FILE=simulation/run_tb.tcl
VSIM_ARGS=-novopt -t 1ps -lib $(WORK_DIR) -do $(TB_TASK_FILE)


all: lib work altera_mf altera vhdlfiles

lib:
	$(MAKE) -C ../Lib -f ../Lib/Makefile

work:
	$(VLIB) $(WORK_DIR)

altera:
	$(VLIB) /tmp/altera
	$(VMAP) altera /tmp/altera
	$(CC) -work altera -2002 \
		-explicit $(QUARTUS_PATH)/eda/sim_lib/altera_primitives_components.vhd \
		-explicit $(QUARTUS_PATH)/eda/sim_lib/altera_primitives.vhd

.PHONY: altera_mf
altera_mf:
	$(VLIB) /tmp/altera_mf
	$(VMAP) altera_mf /tmp/altera_mf
	$(CC) -work altera_mf -2002 \
		-explicit $(QUARTUS_PATH)/eda/sim_lib/altera_mf_components.vhd \
		-explicit $(QUARTUS_PATH)/eda/sim_lib/altera_mf.vhd


clean:
	rm -rf *~ rtl_work *.wlf transcript *.bak

vhdlfiles:
	$(CC) $(FLAGS) $(FILES)

isim: all
	$(VSIM) $(TBTOP) $(VSIM_ARGS)
