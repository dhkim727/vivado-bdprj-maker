#############################################################
# Date: 2021/01/15
# AUTHOR: FARNAM KHALILI MAYBODI
# Description: Universal Makefile for the XSMLL IPs targeting various 
# FPGA boards including the AXIOM, GLUON and the GENESYS2 with various Vivado
# Versions 
 

export VIVADO_VERSION  ?=2025.2
# VIVADO_VERSION  ?=2020.2

include .make_ip_list.env
 
HLS_IP_DIR := hls-ips
VHD_IP_DIR := vhd-ips

FPGA_WORK_ROOT := work-fpga
FPGA_WORK_DIR := $(FPGA_WORK_ROOT)/$(VIVADO_VERSION)/$(BOARD)

# HDL IPs can be listed either through the legacy vhd_ips variable or the
# generic hdl_ips variable in .make_ip_list.env. Supported source suffixes are
# .vhd, .v, and .sv.
hdl_ip_files := $(vhd_ips) $(hdl_ips)

export HLS_IP_DIR
export VHD_IP_DIR
export FPGA_WORK_ROOT
export FPGA_WORK_DIR


ifeq ($(BOARD), m1p)
	XILINX_PART 			 := xcku060-ffva1156-1-i
	CLK_PERIOD_NS			 := 10
else ifeq ($(BOARD), m1p_new)
	XILINX_PART 			 := xcku060-ffva1156-1-i
	CLK_PERIOD_NS			 := 10
else ifeq  ($(BOARD), m1)
	XILINX_PART 			 := xcau25p-ffvb676-2-i
	CLK_PERIOD_NS			 := 10
else
$(error Unknown board - please specify a supported FPGA board)
endif


#hls_ips := $(addprefix $(FPGA_WORK_DIR)/, $(hls_ips))
#hls-ips-target := $(join $(addsuffix /ip/, $(addprefix $(HLS_IP_DIR)/, $(basename $(hls_ips)))), $(hls_ips))

hdl_ips := $(addprefix $(FPGA_WORK_DIR)/, $(hdl_ip_files))
hdl-ips-target := $(join $(addsuffix /ip/, $(addprefix $(VHD_IP_DIR)/, $(basename $(hdl_ips)))), $(hdl_ips))

all: $(hdl_ips)
 
#$(hls_ips): %.vhd : $(vhd_ips)
#	mkdir -p $(FPGA_WORK_DIR)
#	@echo Generating $(@F) with Vivado Version $(VIVADO_VERSION)
#	@cd $(HLS_IP_DIR)/$(basename $(@F)) && make clean && make BOARD=$(BOARD) XILINX_PART=$(XILINX_PART) CLK_PERIOD_NS=$(CLK_PERIOD_NS) VIVADO_VERSION=$(VIVADO_VERSION)
#	@cp $(HLS_IP_DIR)/$(basename $(@F))/$(basename $(@F))/rtl/impl/ip/hdl/vhdl/$(@F:hls_%=%) $@ 


$(FPGA_WORK_DIR)/%.vhd $(FPGA_WORK_DIR)/%.v $(FPGA_WORK_DIR)/%.sv:
	mkdir -p $(FPGA_WORK_DIR)
	@echo Generating $(@F) with Vivado Version $(VIVADO_VERSION)
	@cd $(VHD_IP_DIR)/$(basename $(@F)) && make clean && make BOARD=$(BOARD) XILINX_PART=$(XILINX_PART) CLK_PERIOD_NS=$(CLK_PERIOD_NS) VIVADO_VERSION=$(VIVADO_VERSION) HDL_SOURCE=$(@F)
	@cp $(VHD_IP_DIR)/$(basename $(@F))/$(basename $(@F)).srcs/sources_1/imports/src/$(@F) $@

clean:
	@echo Clean work-fpga 
	@rm -rf $(FPGA_WORK_DIR)
	@rm -f *.log *.jou *.str
	@for ip in $(basename $(hdl_ip_files)); do \
		ip_dir=$(VHD_IP_DIR)/$$ip; \
		if [ -f "$$ip_dir/Makefile" ]; then \
			echo "Cleaning IP: $$ip"; \
			(cd "$$ip_dir" && $(MAKE) clean) || true; \
		fi; \
	done

