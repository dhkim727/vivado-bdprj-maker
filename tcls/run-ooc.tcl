##############################################################################
# DATE:  2022/01/18
# AUTHOR: FARNAM KHALILI MAYBODI
# DESCRIPTION: 
# This tcl file is responsible to generate the output products of the 
# included IPs into the Block Design of the vivado project. Their
# appropriate output products based on the specified board/design will be
# generated consequently into the project runs folder.
##############################################################################
source tcls/settings.tcl

# check if the project is not opened, then open it
FM::open_vivado_project_if_needed

set_param general.maxThreads 8
set_property target_language $FM::HDL_LANGUAGE [current_project]

set_msg_config -id {[Synth 8-5858]} -new_severity "info"
set_msg_config -id {[Synth 8-4480]} -limit 1000
 
FM::print_gvars

# Standalone XCI IPs used by RTL inside BD module references must be available
# before BD IP OOC runs are launched. For example, dec2_filter.sv instantiates
# fir_2dec from srcs/xci/<BOARD>/<DESIGN>/fir_2dec/fir_2dec.xci.
if {[file exists tcls/add-xci-sources.tcl]} {
    source tcls/add-xci-sources.tcl
}

FM::run_ooc_ips

exit
##############################################################################