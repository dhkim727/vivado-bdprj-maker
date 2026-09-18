####################################################################################################
# DATE: 2026/06/06
# DESCRIPTION:
# Export the currently opened/generated Vivado project as a board/design-specific
# project Tcl. This replaces the previous BD Tcl export flow.
####################################################################################################
source tcls/settings.tcl

# Check if the project is not opened, then open it.
FM::open_vivado_project_if_needed

set project_tcl_file [FM::normalize_path_from_root $FM::PROJECT_TCL_FILE]
file mkdir [file dirname $project_tcl_file]

# Keep the current block design saved before exporting the project Tcl when the
# design has a BD. The source-controlled BD location is the authoritative BD
# file used by the project Tcl recreation flow.
set bd_file [FM::find_bd_file]
if {$bd_file ne "" && [file exists $bd_file]} {
    open_bd_design $bd_file
    catch {validate_bd_design -force}
    save_bd_design [current_bd_design]
    close_bd_design [current_bd_design]

    set repo_bd_file [file join $FM::ROOT_PATH srcs bd $FM::BOARD_NAME $FM::DESIGN_NAME ${FM::DESIGN_NAME}.bd]
    file mkdir [file dirname $repo_bd_file]
    if {[file normalize $bd_file] ne [file normalize $repo_bd_file]} {
        file copy -force $bd_file $repo_bd_file
    }
}

# Ensure the exported project Tcl points at repository-managed sources instead
# of generated project-local or stale wrapper paths.
FM::remove_stale_bd_wrapper_files
FM::add_repo_sources

# Back up the incremental synthesis DCP to srcs/dcp/ and remove it from the
# project so write_project_tcl emits a clean Tcl without DCP dependencies.
FM::strip_incremental_dcp_for_export

# Export a reproducible project Tcl:
# -use_bd_files keeps the BD as a source-controlled .bd file.
# -no_copy_sources prevents Vivado project-local source copies.
# -paths_relative_to makes emitted paths relative to the repository root.
set write_project_args [list \
    -force \
    -use_bd_files \
    -no_copy_sources \
    -paths_relative_to $FM::ROOT_PATH \
    -all_properties \
    $project_tcl_file \
]

if {[catch {write_project_tcl {*}$write_project_args} write_project_error]} {
    catch {common::send_msg_id "FM-013" "WARNING" "write_project_tcl with -all_properties failed, retrying without -all_properties: $write_project_error"}
    set write_project_args [list \
        -force \
        -use_bd_files \
        -no_copy_sources \
        -paths_relative_to $FM::ROOT_PATH \
        $project_tcl_file \
    ]
    write_project_tcl {*}$write_project_args
}

 put "Project Tcl is created as $project_tcl_file"
 
 FM::patch_project_tcl_auto_wrapper $project_tcl_file

# Restore the incremental synthesis DCP so subsequent make synth can benefit
# from incremental compilation.
FM::restore_incremental_dcp
  
  exit
#####################################################################################################