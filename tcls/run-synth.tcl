##########################################################################################################################
# DATE:  2022/01/18
# AUTHOR: FARNAM KHALILI MAYBODI
# DESCRIPTION: 
# This tcl file is responsible to synthesize the Vivado project, and open the synthesized design and generate
# appropriate report files based on the specified board (i.e., BOARD) by the user during the "make synth". 
##########################################################################################################################
source tcls/settings.tcl

# check if the project is not opened, then open it
FM::open_vivado_project_if_needed


set_param general.maxThreads 8
set_property target_language $FM::HDL_LANGUAGE [current_project]

set_msg_config -id {[Synth 8-5858]} -new_severity "info"
set_msg_config -id {[Synth 8-4480]} -limit 1000


# Standalone XCI IPs must be available before BD IP read_xci
if {[file exists tcls/add-xci-sources.tcl]} {
    source tcls/add-xci-sources.tcl
}

FM::read_xci

# Ensure the BD HDL wrapper is generated, tracked by sources_1, and selected as top.
FM::refresh_bd_wrapper

update_ip_catalog
update_compile_order -fileset sources_1

reset_run synth_1

launch_runs synth_1
wait_on_run synth_1

open_run synth_1

set report_dir $FM::VIVADO_PROJECT/reports
file mkdir $report_dir
file delete -force $report_dir/*

check_timing -verbose                                                   -file $report_dir/check_timing.rpt
report_timing -max_paths 100 -nworst 100 -delay_type max -sort_by slack -file $report_dir/timing_WORST_100.rpt
report_timing -nworst 1 -delay_type max -sort_by group                  -file $report_dir/timing.rpt
report_utilization -hierarchical                                        -file $report_dir/utilization.rpt
report_cdc                                                              -file $report_dir/cdc.rpt
report_clock_interaction  
###########################################################################################################################
