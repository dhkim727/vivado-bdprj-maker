###############################################################################################
# TCL (VIVADO) for packaging control_logic IP
# Based on your_sv_ip_1 template, extended for multi-file + AXI-Lite + reset interfaces.
###############################################################################################

set partNumber $::env(XILINX_PART)
set ipName $::env(PROJECT)
set moduleName $::env(MODULE)

create_project $ipName . -force -part $partNumber
set_property target_language Verilog [current_project]

set src_files [glob -nocomplain src/*.v src/*.sv src/*.vhd src/*.vhdl]
if {[llength $src_files] == 0} {
    error "No HDL source files found in src/"
}

import_files -norecurse {*}$src_files

foreach f $src_files {
    set fObj [get_files -quiet [file tail $f]]
    if {$fObj ne ""} {
        set ext [string tolower [file extension $f]]
        if {$ext eq ".sv" || $ext eq ".svh"} {
            set_property file_type SystemVerilog $fObj
        }
    }
}

set_property top $moduleName [current_fileset]
update_compile_order -fileset sources_1

ipx::package_project -root_dir $ipName -vendor xilinx.com -library user -taxonomy /UserIP
set core [ipx::current_core]

ipx::associate_bus_interfaces -busif S00_AXI -clock s00_axi_aclk $core

set mem_map [ipx::get_memory_maps S00_AXI -of_objects $core]
if {$mem_map ne ""} {
    set addr_block [ipx::get_address_blocks S00_AXI_reg -of_objects $mem_map]
    if {$addr_block ne ""} {
        set_property range 4096 $addr_block
        set_property width 32 $addr_block
    }
}

foreach rst_port {DAC_RESET PLL_RESET RF_VGA_RST RXM_RESET TXM_RESET} {
    set existing_busif [ipx::get_bus_interfaces $rst_port -of_objects $core]
    if {$existing_busif eq ""} {
        ipx::add_bus_interface $rst_port $core
        set busif [ipx::get_bus_interfaces $rst_port -of_objects $core]
        set_property interface_mode master $busif
        ipx::associate_bus_interfaces -clock s00_axi_aclk $core
        set abstraction [ipx::get_abstraction_definitions \
            -vendor xilinx.com -library signal -name reset_rtl -version 1.0]
        set bus_type [ipx::get_bus_definitions \
            -vendor xilinx.com -library signal -name reset -version 1.0]
        set_property bus_type_vlnv $bus_type $busif
        set_property abstraction_type_vlnv $abstraction $busif

        ipx::add_port_map RST $busif
        set port_map [ipx::get_port_maps RST -of_objects $busif]
        set_property physical_name $rst_port $port_map
    }
}

ipx::add_file_group -type utility {} $core
ipx::add_file ../../logo.png [ipx::get_file_groups xilinx_utilityxitfiles -of_objects $core]
set_property type image [ipx::get_files ../../logo.png -of_objects [ipx::get_file_groups xilinx_utilityxitfiles -of_objects $core]]
set_property type LOGO [ipx::get_files ../../logo.png -of_objects [ipx::get_file_groups xilinx_utilityxitfiles -of_objects $core]]

ipx::create_xgui_files $core
ipx::update_checksums $core
ipx::save_core $core

set_property ip_repo_paths $ipName [current_project]
update_ip_catalog
###############################################################################################