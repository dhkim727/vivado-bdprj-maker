#########################################################################################################################
# DATE:  2026/06/05
# DESCRIPTION:
# Export a Vivado hardware platform (XSA) from an already implemented project.
# This script is used by "make xsa" and does not run synthesis or implementation.
#########################################################################################################################
source tcls/settings.tcl

# check if the project is not opened, then open it
FM::open_vivado_project_if_needed

set_param general.maxThreads 8
set_property target_language $FM::HDL_LANGUAGE [current_project]

set xsa_dir $FM::VIVADO_PROJECT/$FM::VIVADO_PROJECT_NAME.sdk
set xsa_file $xsa_dir/${FM::DESIGN_NAME}_wrapper.xsa

file mkdir $xsa_dir

open_run impl_1
write_hw_platform -fixed -include_bit -force $xsa_file

put "XSA file is created as $xsa_file"

exit
#########################################################################################################################
