FILES=source/DramTestPack.vhd \
	ReqFifo.vhd \
	RespFIFO.vhd \
	PLL.vhd \
	AsyncFifo.vhd \
	source/ServoPack.vhd \
	source/PWMCtrl.vhd \
	source/ObjectFinder.vhd \
	source/FloydSteinberg2PRAM.vhd \
	source/DitherFloydSteinberg.vhd \
	source/LineSampler1PRAM.vhd \
	source/LineSampler.vhd \
	source/ConvFilter.vhd \
	source/MedianFilter.vhd \
	source/FilterChain.vhd \
	source/SramArbiter.vhd \
	source/PixelAligner.vhd \
	source/TemporalDiff.vhd \
	source/TemporalAverager.vhd \
	source/CamCapture.vhd \
	source/SccbCtrl.vhd \
	source/OV7660Init.vhd \
	source/SccbMaster.vhd \
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

IP_VLOG_FILES=../ip/H57V2562GTR.v

WORK_DIR="/tmp/work"
MODELSIMINI_PATH=./modelsim.ini

QUARTUS_PATH=/opt/altera/13.0sp1/quartus

VHDL=vcom
VHDL_FLAGS=-93
VLOG=vlog
VLOG_FLAGS=+nospecify
FLAGS=-work $(WORK_DIR) -modelsimini $(MODELSIMINI_PATH)
VMAP=vmap
VLIB=vlib
VSIM=vsim
TBTOP=tb

TB_TASK_FILE=simulation/run_tb.tcl
VSIM_ARGS=-novopt -t 1ps -lib $(WORK_DIR) -do $(TB_TASK_FILE)

all: lib work altera_mf altera sramcontroller vlogipfiles vhdlfiles

lib:
	$(MAKE) -C ../Lib -f ../Lib/Makefile

work:
	$(VLIB) $(WORK_DIR)

altera:
	$(VLIB) /tmp/altera
	$(VMAP) altera /tmp/altera
	$(VHDL) -work altera -2002 \
		-explicit $(QUARTUS_PATH)/eda/sim_lib/altera_primitives_components.vhd \
		-explicit $(QUARTUS_PATH)/eda/sim_lib/altera_primitives.vhd

.PHONY: altera_mf
altera_mf:
	$(VLIB) /tmp/altera_mf
	$(VMAP) altera_mf /tmp/altera_mf
	$(VHDL) -work altera_mf -2002 \
		-explicit $(QUARTUS_PATH)/eda/sim_lib/altera_mf_components.vhd \
		-explicit $(QUARTUS_PATH)/eda/sim_lib/altera_mf.vhd

clean:
	rm -rf *~ \
		rtl_work \
		*.wlf \
		transcript \
		*.bak \
		source/*~ \
		source/*.bak \
		output_files

vhdlfiles:
	$(VHDL) $(VHDL_FLAGS) $(FLAGS) $(FILES)

vlogipfiles:
	$(VLOG) $(FLAGS) $(VLOG_FLAGS) $(IP_VLOG_FILES)

isim: all
	$(VSIM) $(TBTOP) $(VSIM_ARGS)

sramcontroller:
	@$(MAKE) -C ../SramTest-IS61LV25616AL -f ../SramTest-IS61LV25616AL/Makefile
