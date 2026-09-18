#####################################################################################################
# DATE: 2021/01/15
# AUTHOR: FARNAM KHALILI MAYBODI
# DESCRIPTION: 
# Universal Makefile for handling a vivado project from IP design, generation,
# packaging IPs, vivado project creation, IP OOC (Out of Context) runs, synthesize
# implementation, bitstream generation, report generation, for target board defined
# by the user through the $BOARD.
# The following environment variable can be set by the user:
#BOARD			?= m1p
#DESIGN			?= system

#BOARD			?= m1p_new
#DESIGN			?= bd_design

BOARD           ?= m1
DESIGN          ?= bd_design

export VIVADO_VERSION  ?=2025.2
HDL_LANGUAGE    ?= VERILOG
# DRAM 64GB PC기준으로 SWAP 공간 최소 64GB로 잡아야 OOC 시 튕기지 않음
OOC_THREADS     ?= 8 
# setting additional xilinx board parameters for the selected board
ifeq ($(BOARD), m1p)
	XILINX_PART 			 := xcku060-ffva1156-1-i
	CLK_PERIOD_NS			 := 10
	AUTO_WRAPPER			 := 1
else ifeq ($(BOARD), m1p_new)
	XILINX_PART 			 := xcku060-ffva1156-1-i
	CLK_PERIOD_NS			 := 10
	AUTO_WRAPPER			 := 0
else ifeq  ($(BOARD), m1)
	XILINX_PART 			 := xcau25p-ffvb676-2-i
	CLK_PERIOD_NS			 := 10
	AUTO_WRAPPER			 := 0
else
$(error Unknown board - please specify a supported FPGA board)
endif
######################################################################################################


######################################################################################################
# Do not touch from here:
######################################################################################################
MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
export ROOT_PATH   := $(dir $(MKFILE_PATH))

HLS_IP_DIR := hls-ips
VHD_IP_DIR := vhd-ips
VIVADO_WORK_ROOT := vivado-prj
VIVADO_WORK_DIR := $(VIVADO_WORK_ROOT)/$(BOARD)/$(DESIGN)
VIVADO_PROJECT_NAME := $(BOARD)-$(DESIGN)-vivado
VIVADO_PROJECT_DIR := $(VIVADO_WORK_DIR)/$(VIVADO_PROJECT_NAME)
PROJECT_TCL_DIR := tcls/project/$(BOARD)/$(DESIGN)
PROJECT_TCL_FILE := $(PROJECT_TCL_DIR)/project-src.tcl

export HLS_IP_DIR
export VHD_IP_DIR
export XILINX_PART
export BOARD
export DESIGN
export VIVADO_WORK_ROOT
export VIVADO_WORK_DIR
export VIVADO_PROJECT_NAME
export VIVADO_PROJECT_DIR
export PROJECT_TCL_DIR
export PROJECT_TCL_FILE
export HDL_LANGUAGE
export OOC_THREADS
export AUTO_WRAPPER

all:
	$(MAKE) synth
	$(MAKE) impl
	$(MAKE) xsa
 
vivado: custom_ips 
	@echo Creating Vivado Project 
	@mkdir -p ${VIVADO_WORK_DIR}
	@cd ${VIVADO_WORK_DIR} 
	vivado -mode batch -source tcls/run-vivado-prj.tcl  -nolog -nojournal 
	@mkdir -p ${VIVADO_PROJECT_DIR}/${VIVADO_PROJECT_NAME}.srcs/sources_1/bd/${DESIGN}/ui
	@if [ -d srcs/stored_ui/${BOARD}/${DESIGN} ]; then cp srcs/stored_ui/${BOARD}/${DESIGN}/* ${VIVADO_PROJECT_DIR}/${VIVADO_PROJECT_NAME}.srcs/sources_1/bd/${DESIGN}/ui/ 2>/dev/null || true; fi

update_tcl:
	@echo Updating ${PROJECT_TCL_FILE}
	@cd ${VIVADO_WORK_DIR}
	@mkdir -p ${PROJECT_TCL_DIR}
	@mkdir -p srcs/bd/${BOARD}/${DESIGN}
	@mkdir -p srcs/bd_old/${BOARD}/${DESIGN}
	@mkdir -p srcs/stored_ui/${BOARD}/${DESIGN}
	@if [ -f ${VIVADO_PROJECT_DIR}/${VIVADO_PROJECT_NAME}.srcs/sources_1/bd/${DESIGN}/${DESIGN}.bd ]; then cp ${VIVADO_PROJECT_DIR}/${VIVADO_PROJECT_NAME}.srcs/sources_1/bd/${DESIGN}/${DESIGN}.bd srcs/bd_old/${BOARD}/${DESIGN}/; elif [ -f ${VIVADO_WORK_DIR}/${VIVADO_PROJECT_NAME}.srcs/sources_1/bd/${DESIGN}/${DESIGN}.bd ]; then cp ${VIVADO_WORK_DIR}/${VIVADO_PROJECT_NAME}.srcs/sources_1/bd/${DESIGN}/${DESIGN}.bd srcs/bd_old/${BOARD}/${DESIGN}/; fi
	@if [ -d ${VIVADO_PROJECT_DIR}/${VIVADO_PROJECT_NAME}.srcs/sources_1/bd/${DESIGN}/ui ]; then cp ${VIVADO_PROJECT_DIR}/${VIVADO_PROJECT_NAME}.srcs/sources_1/bd/${DESIGN}/ui/* srcs/stored_ui/${BOARD}/${DESIGN}/ 2>/dev/null || true; elif [ -d ${VIVADO_WORK_DIR}/${VIVADO_PROJECT_NAME}.srcs/sources_1/bd/${DESIGN}/ui ]; then cp ${VIVADO_WORK_DIR}/${VIVADO_PROJECT_NAME}.srcs/sources_1/bd/${DESIGN}/ui/* srcs/stored_ui/${BOARD}/${DESIGN}/ 2>/dev/null || true; fi
	vivado -mode batch -source tcls/gen-project-tcl.tcl  -nolog -nojournal

ip_ooc:
	@echo Running IP OOC for existing Vivado project
	@cd ${VIVADO_WORK_DIR}
	vivado -mode batch -source tcls/run-ooc.tcl -nolog -nojournal 
	wait; 

synth:
	@echo Running OOC and synthesizing existing Vivado project
	$(MAKE) ip_ooc
	vivado -mode batch -source tcls/run-synth.tcl -nolog -nojournal 

impl:
	@echo Implementing existing synthesized Vivado project and generating bitstream
	vivado -mode batch -source tcls/run-impl.tcl -nolog -nojournal



xsa:
	@echo Exporting XSA file ....
	vivado -mode batch -source tcls/run-xsa.tcl -nolog -nojournal


custom_ips:
	@echo Make IPs which are located into the folder "ips" 
	@cd ips && make all 

clean:
	@echo Clean ...
	rm -rf *.log *.jou .Xil 
	@cd ips && make clean
	git clean -fdX -- srcs/bd/
       	
########################################################################################################
