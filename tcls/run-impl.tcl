#########################################################################################################################
# DATE:  2022/01/18
# AUTHOR: FARNAM KHALILI MAYBODI
# DESCRIPTION: 
# This tcl file is responsible to implement (placement, optimization, route, and bitstream generation) the design that 
# is already synthesized. The command to issue this tcl is "make impl".
##########################################################################################################################
source tcls/settings.tcl

# check if the project is not opened, then open it
FM::open_vivado_project_if_needed

set_param general.maxThreads 8
set_property target_language $FM::HDL_LANGUAGE [current_project]


reset_run impl_1

launch_runs impl_1
wait_on_run impl_1

launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1

open_run impl_1

#output Verilog netlist + SDC for timing simulation
write_verilog -force -mode funcsim $FM::VIVADO_PROJECT/$FM::VIVADO_PROJECT_NAME.funcsim.v
write_verilog -force -mode timesim $FM::VIVADO_PROJECT/$FM::VIVADO_PROJECT_NAME.timesim.v
write_sdf     -force $FM::VIVADO_PROJECT/$FM::VIVADO_PROJECT_NAME.timesim.sdf
#
# # reports
set report_dir $FM::VIVADO_PROJECT/reports
file mkdir $report_dir
file delete -force $report_dir/*
check_timing                                                              -file $report_dir/check_timing.rpt
report_timing -max_paths 100 -nworst 100 -delay_type max -sort_by slack   -file $report_dir/timing_WORST_100.rpt
report_timing -nworst 1 -delay_type max -sort_by group                    -file $report_dir/timing.rpt
report_utilization -hierarchical                                          -file $report_dir/utilization.rpt

exit
#############################################################################################################################
