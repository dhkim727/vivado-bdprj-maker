##################################################################################
# DATE:  2022/01/18
# AUTHOR: FARNAM KHALILI MAYBODI
# DESCRIPTION: 
# This Tcl file creates a Vivado project from a board/design-specific project Tcl.
# The project Tcl is expected to be exported by make update_tcl with repository
# relative source paths.
##################################################################################
source tcls/settings.tcl

set project_tcl [FM::normalize_path_from_root $FM::PROJECT_TCL_FILE]

if {![file exists $project_tcl]} {
      catch {common::send_msg_id "FM-001" "ERROR" "Project Tcl does not exist: $project_tcl"}
      exit 1
}

set ::origin_dir_loc $FM::ROOT_PATH
set ::user_project_name $FM::VIVADO_PROJECT_NAME

set_param general.maxThreads 8

set_msg_config -id {[Synth 8-5858]} -new_severity "info"
set_msg_config -id {[Synth 8-4480]} -limit 1000

put $FM::PART_NAME
put $FM::BOARD_NAME
put $FM::PROJECT_TCL_FILE
put $project_tcl

file mkdir $FM::VIVADO_PROJECT
cd $FM::VIVADO_PROJECT
FM::rewrite_repo_generated_output_paths

if {[get_projects -quiet] ne ""} {
      close_project
}

source $project_tcl

set_property target_language $FM::HDL_LANGUAGE [current_project]

# Re-attach repository-managed sources and constraints after the exported project
# Tcl has created the project. This preserves the historical srcs/ and
# constraints/ layout while replacing the former BD Tcl source flow.
FM::add_repo_sources


#if your project has HDL_LANGUAGE libraries please add here with the specific tcl proc that we defined: 
#example:
#FM::read_user_lib_1
#FM::read_user_lib_2


#if there are source files
#please add your *.vhd *.sv, *.v sources 
#here. 
# source add_sources.tcl
#if your design does not include block design, you must specify the top module of your design here:
# set_property top <the entity name of your top module hdl code> [current_fileset]

# If your project contains a block design, automatically create or refresh the
# HDL wrapper, add it to the project if needed, and make it the top module.
FM::refresh_bd_wrapper

# Restore incremental synthesis DCP from srcs/dcp/ if available, so that
# make synth can benefit from incremental compilation.
FM::restore_incremental_dcp

update_compile_order -fileset sources_1

exit
##################################################################################
