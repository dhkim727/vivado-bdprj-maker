#######################################################################################################
# AUTHOR: FARNAM KHALILI MAYBODI
# DATE: 2022/02/05
# The environment variables, and processes are defined here
#######################################################################################################

namespace eval ::FM {

	variable VIVADO_PROJECT
	variable VIVADO_PROJECT_NAME
	variable PART_NAME
	variable BOARD_NAME
	variable DESIGN_NAME
	variable PROJECT_TCL_FILE
	variable ROOT_PATH
	variable HDL_LANGUAGE
	variable OOC_THREADS
	variable AUTO_WRAPPER

	proc print_gvars {} {
      		put $FM::VIVADO_PROJECT
		put $FM::VIVADO_PROJECT_NAME
      		put $FM::PART_NAME
      		put $FM::BOARD_NAME
		put $FM::DESIGN_NAME
		put $FM::PROJECT_TCL_FILE
      		put $FM::HDL_LANGUAGE
      		put $FM::OOC_THREADS
	}

	proc normalize_path_from_root {path_value} {
		if {[file pathtype $path_value] eq "absolute"} {
			return [file normalize $path_value]
		}

		return [file normalize [file join $FM::ROOT_PATH $path_value]]
	}

	proc relative_path {from_dir to_path} {
		set from_parts [file split [file normalize $from_dir]]
		set to_parts [file split [file normalize $to_path]]
		set from_count [llength $from_parts]
		set to_count [llength $to_parts]
		set common_count 0

		while {$common_count < $from_count && $common_count < $to_count} {
			if {[lindex $from_parts $common_count] ne [lindex $to_parts $common_count]} {
				break
			}
			incr common_count
		}

		set relative_parts {}
		for {set part_index $common_count} {$part_index < $from_count} {incr part_index} {
			lappend relative_parts ..
		}

		foreach to_part [lrange $to_parts $common_count end] {
			lappend relative_parts $to_part
		}

		if {[llength $relative_parts] == 0} {
			return .
		}

		return [file join {*}$relative_parts]
	}

	proc vivado_project_dir {} {
		return [file normalize [file join $FM::VIVADO_PROJECT $FM::VIVADO_PROJECT_NAME]]
	}

	proc vivado_project_xpr_candidates {} {
		return [list \
			[file join [FM::vivado_project_dir] ${FM::VIVADO_PROJECT_NAME}.xpr] \
			[file join $FM::VIVADO_PROJECT ${FM::VIVADO_PROJECT_NAME}.xpr] \
		]
	}

	proc find_vivado_project_xpr {} {
		foreach project_xpr [FM::vivado_project_xpr_candidates] {
			set normalized_project_xpr [file normalize $project_xpr]
			if {[file exists $normalized_project_xpr]} {
				return $normalized_project_xpr
			}
		}

		return ""
	}

	proc open_vivado_project_if_needed {} {
		if {[get_projects -quiet] ne ""} {
			return
		}

		set project_xpr [FM::find_vivado_project_xpr]
		if {$project_xpr eq ""} {
			catch {common::send_msg_id "FM-014" "ERROR" "Vivado project XPR does not exist. Checked paths: [join [FM::vivado_project_xpr_candidates] {, }]"}
			exit 1
		}

		open_project $project_xpr
	}

	proc current_vivado_project_dir {} {
		if {[get_projects -quiet] ne ""} {
			return [file normalize [get_property directory [current_project]]]
		}

		return [FM::vivado_project_dir]
	}

	proc filter_existing_files {files} {
		set existing_files {}

		foreach file_value $files {
			set normalized_file [file normalize $file_value]
			if {[file exists $normalized_file]} {
				lappend existing_files $normalized_file
			} else {
				catch {common::send_msg_id "FM-007" "WARNING" "Skipping missing project Tcl source: $normalized_file"}
			}
		}

		return $existing_files
	}

	proc safe_set_property {args} {
		set objects [lindex $args end]
		if {$objects eq ""} {
			catch {common::send_msg_id "FM-010" "WARNING" "Skipping set_property because object list is empty: $args"}
			return
		}

		uplevel 1 [list set_property {*}$args]
	}

	proc collect_xdc_files_recursive {root_dir} {
		set collected_files {}

		if {![file exists $root_dir]} {
			return $collected_files
		}

		foreach entry [glob -nocomplain -directory $root_dir *] {
			if {[file isdirectory $entry]} {
				set child_files [FM::collect_xdc_files_recursive $entry]
				foreach child_file $child_files {
					lappend collected_files $child_file
				}
			} elseif {[string tolower [file extension $entry]] eq ".xdc"} {
				lappend collected_files [file normalize $entry]
			}
		}

		return [lsort -unique $collected_files]
	}

	proc collect_project_metadata_files_recursive {root_dir} {
		set collected_files {}

		if {![file exists $root_dir]} {
			return $collected_files
		}

		foreach entry [glob -nocomplain -directory $root_dir *] {
			if {[file isdirectory $entry]} {
				set child_files [FM::collect_project_metadata_files_recursive $entry]
				foreach child_file $child_files {
					lappend collected_files $child_file
				}
			} else {
				set lower_extension [string tolower [file extension $entry]]
				if {$lower_extension eq ".bd" || $lower_extension eq ".xci"} {
					lappend collected_files [file normalize $entry]
				}
			}
		}

		return [lsort -unique $collected_files]
	}

	proc rewrite_generated_output_paths_in_file {metadata_file} {
		set normalized_metadata_file [file normalize $metadata_file]
		if {![file exists $normalized_metadata_file]} {
			return
		}

		set project_gen_dir [file join [FM::vivado_project_dir] ${FM::VIVADO_PROJECT_NAME}.gen]
		set replacement_gen_dir [FM::relative_path [file dirname $normalized_metadata_file] $project_gen_dir]

		set metadata_fd [open $normalized_metadata_file r]
		set metadata_content [read $metadata_fd]
		close $metadata_fd

		set rewritten_content $metadata_content

		if {[string tolower [file extension $normalized_metadata_file]] eq ".xci"} {
			set ip_name [file rootname [file tail $normalized_metadata_file]]
			set ip_gen_dir ${replacement_gen_dir}/sources_1/ip/${ip_name}
			regsub -all {("gen_directory": ")[^"]*(")} $rewritten_content "\\1${ip_gen_dir}\\2" rewritten_content
			regsub -all {("OUTPUTDIR": \[ \{ "value": ")[^"]*(" \} \])} $rewritten_content "\\1${ip_gen_dir}\\2" rewritten_content
		} else {
			regsub -all {(\.\./)*vivado-prj/[^"[:space:]]*\.gen} $rewritten_content $replacement_gen_dir rewritten_content
		}

		if {$rewritten_content ne $metadata_content} {
			puts "Rewriting generated output directory metadata: $normalized_metadata_file"
			set metadata_fd [open $normalized_metadata_file w]
			puts -nonewline $metadata_fd $rewritten_content
			close $metadata_fd
		}
	}

	proc rewrite_repo_generated_output_paths {} {
		set metadata_roots [list \
			[file join $FM::ROOT_PATH srcs bd $FM::BOARD_NAME $FM::DESIGN_NAME] \
			[file join $FM::ROOT_PATH srcs xci $FM::BOARD_NAME $FM::DESIGN_NAME] \
		]

		foreach metadata_root $metadata_roots {
			foreach metadata_file [FM::collect_project_metadata_files_recursive $metadata_root] {
				FM::rewrite_generated_output_paths_in_file $metadata_file
			}
		}
	}

	proc add_board_constraints {} {
		set board_constraint_dir [file join $FM::ROOT_PATH constraints $FM::BOARD_NAME]
		set board_xdc_files [FM::collect_xdc_files_recursive $board_constraint_dir]

		if {[llength $board_xdc_files] > 0} {
			puts "Adding board constraint files: $board_xdc_files"
			add_files -fileset constrs_1 -norecurse $board_xdc_files
		}
	}

	proc add_repo_sources {} {
		set old_pwd [pwd]
		cd $FM::ROOT_PATH

		FM::add_board_constraints

		set_property ip_repo_paths [list [file join $FM::ROOT_PATH ips]] [get_filesets sources_1]
		update_ip_catalog

		if {[file exists [file join $FM::ROOT_PATH tcls add-xci-sources.tcl]]} {
			source [file join $FM::ROOT_PATH tcls add-xci-sources.tcl]
		}

		if {[file exists [file join $FM::ROOT_PATH tcls add-rtl-sources.tcl]]} {
			source [file join $FM::ROOT_PATH tcls add-rtl-sources.tcl]
		}

		update_compile_order -fileset sources_1
		cd $old_pwd
	}

	proc find_bd_file {} {
		set project_dir [FM::current_vivado_project_dir]
		set candidates [list \
			[file join $project_dir ${FM::VIVADO_PROJECT_NAME}.srcs sources_1 bd $FM::DESIGN_NAME ${FM::DESIGN_NAME}.bd] \
			[file join $FM::VIVADO_PROJECT ${FM::VIVADO_PROJECT_NAME}.srcs sources_1 bd $FM::DESIGN_NAME ${FM::DESIGN_NAME}.bd] \
			[file join $FM::ROOT_PATH srcs bd $FM::BOARD_NAME $FM::DESIGN_NAME ${FM::DESIGN_NAME}.bd] \
		]

		foreach candidate $candidates {
			set normalized_candidate [file normalize $candidate]
			if {[file exists $normalized_candidate]} {
				return $normalized_candidate
			}
		}

		set bd_files [get_files -quiet -of_objects [get_filesets sources_1] *$FM::DESIGN_NAME.bd]
		if {$bd_files ne ""} {
			return [lindex $bd_files 0]
		}

		set bd_files [get_files -quiet *$FM::DESIGN_NAME.bd]
		if {$bd_files ne ""} {
			return [lindex $bd_files 0]
		}

		return ""
	}

	proc collect_named_files_recursive {root_dir file_name} {
		set collected_files {}

		if {![file exists $root_dir]} {
			return $collected_files
		}

		foreach entry [glob -nocomplain -directory $root_dir *] {
			if {[file isdirectory $entry]} {
				set child_files [FM::collect_named_files_recursive $entry $file_name]
				foreach child_file $child_files {
					lappend collected_files $child_file
				}
			} elseif {[file tail $entry] eq $file_name} {
				lappend collected_files [file normalize $entry]
			}
		}

		return [lsort -unique $collected_files]
	}

	proc remove_stale_bd_wrapper_files {} {
		set stale_wrapper_patterns [list \
			*${FM::DESIGN_NAME}_wrapper.v \
			*${FM::DESIGN_NAME}_wrapper.vhd \
		]

		foreach stale_wrapper_pattern $stale_wrapper_patterns {
			set wrapper_files [get_files -quiet -of_objects [get_filesets sources_1] $stale_wrapper_pattern]
			foreach wrapper_file $wrapper_files {
				set wrapper_name [file normalize $wrapper_file]
				if {![file exists $wrapper_name]} {
					puts "Removing stale BD wrapper source from project: $wrapper_file"
					remove_files -quiet $wrapper_file
				}
			}
		}
	}

	proc refresh_bd_wrapper {} {
		set bd_file [FM::find_bd_file]
		set project_dir [FM::current_vivado_project_dir]

		if {$bd_file eq "" || ![file exists $bd_file]} {
			catch {common::send_msg_id "FM-004" "ERROR" "BD file does not exist for design: $FM::DESIGN_NAME"}
			exit 1
		}

		FM::remove_stale_bd_wrapper_files

		catch {open_bd_design $bd_file}
		catch {save_bd_design}

		set bd_files [get_files -quiet $bd_file]
		if {$bd_files eq ""} {
			add_files -fileset sources_1 -norecurse $bd_file
			set bd_files [get_files -quiet $bd_file]
		}
		if {$bd_files eq ""} {
			set bd_files [get_files -quiet -of_objects [get_filesets sources_1] *$FM::DESIGN_NAME.bd]
		}
		if {$bd_files eq ""} {
			set bd_files [get_files -quiet *$FM::DESIGN_NAME.bd]
		}
		if {$bd_files eq ""} {
			catch {common::send_msg_id "FM-005" "ERROR" "BD file is not tracked by project sources_1: $bd_file"}
			exit 1
		}

		put "Refresh Block Design HDL wrapper for: $bd_file"
		catch {generate_target all $bd_files}
		set wrapper_path ""
		catch {set wrapper_path [make_wrapper -files $bd_files -top -force]}

		if {[get_property target_language [current_project]] eq "VHDL"} {
			set wrapper_ext vhd
		} else {
			set wrapper_ext v
		}

		set wrapper_candidates [list \
			{*}$wrapper_path \
			[file join $project_dir ${FM::VIVADO_PROJECT_NAME}.gen sources_1 bd $FM::DESIGN_NAME hdl ${FM::DESIGN_NAME}_wrapper.$wrapper_ext] \
			[file join $project_dir ${FM::VIVADO_PROJECT_NAME}.srcs sources_1 bd $FM::DESIGN_NAME hdl ${FM::DESIGN_NAME}_wrapper.$wrapper_ext] \
			[file join $FM::VIVADO_PROJECT ${FM::VIVADO_PROJECT_NAME}.gen sources_1 bd $FM::DESIGN_NAME hdl ${FM::DESIGN_NAME}_wrapper.$wrapper_ext] \
			[file join $FM::VIVADO_PROJECT ${FM::VIVADO_PROJECT_NAME}.srcs sources_1 bd $FM::DESIGN_NAME hdl ${FM::DESIGN_NAME}_wrapper.$wrapper_ext] \
		]

		foreach wrapper_file_obj [get_files -quiet -of_objects [get_filesets sources_1] *${FM::DESIGN_NAME}_wrapper.$wrapper_ext] {
			lappend wrapper_candidates $wrapper_file_obj
		}

		foreach discovered_wrapper [FM::collect_named_files_recursive $project_dir ${FM::DESIGN_NAME}_wrapper.$wrapper_ext] {
			lappend wrapper_candidates $discovered_wrapper
		}

		foreach discovered_wrapper [FM::collect_named_files_recursive $FM::VIVADO_PROJECT ${FM::DESIGN_NAME}_wrapper.$wrapper_ext] {
			lappend wrapper_candidates $discovered_wrapper
		}

		set wrapper_file ""
		foreach wrapper_candidate $wrapper_candidates {
			if {$wrapper_candidate ne ""} {
				set normalized_wrapper_candidate [file normalize $wrapper_candidate]
				if {[file exists $normalized_wrapper_candidate]} {
					set wrapper_file $normalized_wrapper_candidate
					break
				}
			}
		}

		if {$wrapper_file ne ""} {
			if {[get_files -quiet $wrapper_file] eq ""} {
				add_files -fileset sources_1 -norecurse $wrapper_file
			}
			if {$FM::AUTO_WRAPPER != 0} {
				set_property top ${FM::DESIGN_NAME}_wrapper [get_filesets sources_1]
				update_compile_order -fileset sources_1
				set_property top ${FM::DESIGN_NAME}_wrapper [get_filesets sources_1]
			}
		} else {
			catch {common::send_msg_id "FM-006" "ERROR" "BD wrapper file was not created. Checked paths: [join $wrapper_candidates {, }]"}
			exit 1
		}
	}

	proc strip_dcp_from_project_tcl {project_tcl_file} {
		set normalized_file [file normalize $project_tcl_file]
		if {![file exists $normalized_file]} {
			return
		}

		set fd [open $normalized_file r]
		set content [read $fd]
		close $fd

		set lines [split $content \n]
		set output_lines {}
		set skip_until_blank 0

		foreach line $lines {
			if {$skip_until_blank} {
				if {[string trim $line] eq ""} {
					set skip_until_blank 0
					lappend output_lines $line
				}
				continue
			}

			if {[regexp {^\s*set\s+file\s+\".*\.dcp\"\s*$} $line]} {
				set skip_until_blank 1
				continue
			}

			if {![regexp {^\s*#} $line] && [regexp {\.dcp} $line]} {
				continue
			}

			lappend output_lines $line
		}

		set rewritten_content [join $output_lines \n]

		regsub -all {set added_files \[add_files -fileset utils_1 \$files\]} $rewritten_content {if {[llength $files] > 0} { set added_files [add_files -fileset utils_1 $files] }} rewritten_content

		if {$rewritten_content ne $content} {
			puts "Stripping DCP references from project Tcl: $normalized_file"
			set fd [open $normalized_file w]
			puts -nonewline $fd $rewritten_content
			close $fd
		}
	}

	proc patch_project_tcl_auto_wrapper {project_tcl_file} {
		strip_dcp_from_project_tcl $project_tcl_file
	}

	proc strip_incremental_dcp_for_export {} {
		set synth_run [get_runs -quiet synth_1]
		if {$synth_run eq ""} {
			return ""
		}

		set dcp_path [get_property -quiet incremental_checkpoint $synth_run]
		if {$dcp_path eq ""} {
			return ""
		}

		set dcp_path [file normalize $dcp_path]
		if {![file exists $dcp_path]} {
			catch {set_property incremental_checkpoint "" $synth_run}
			return ""
		}

		set repo_dcp_dir [file join $FM::ROOT_PATH srcs dcp $FM::BOARD_NAME $FM::DESIGN_NAME]
		file mkdir $repo_dcp_dir
		set repo_dcp_file [file join $repo_dcp_dir [file tail $dcp_path]]
		file copy -force $dcp_path $repo_dcp_file
		puts "Backed up incremental synthesis DCP to: $repo_dcp_file"

		set utils_fileset [get_filesets -quiet utils_1]
		if {$utils_fileset ne ""} {
			catch {
				set dcp_files [get_files -quiet -of_objects $utils_fileset "*.dcp"]
				foreach dcp_file $dcp_files {
					remove_files $dcp_file
				}
			}
		}

		catch {set_property incremental_checkpoint "" $synth_run}
		puts "Cleared incremental_checkpoint from synth_1 for clean project Tcl export"

		return $dcp_path
	}

	proc restore_incremental_dcp {} {
		set repo_dcp_dir [file join $FM::ROOT_PATH srcs dcp $FM::BOARD_NAME $FM::DESIGN_NAME]
		if {![file exists $repo_dcp_dir]} {
			return
		}

		set dcp_files [glob -nocomplain -directory $repo_dcp_dir *.dcp]
		if {[llength $dcp_files] == 0} {
			return
		}

		set dcp_file [file normalize [lindex $dcp_files 0]]
		set project_dir [FM::current_vivado_project_dir]
		set utils_dcp_dir [file join $project_dir ${FM::VIVADO_PROJECT_NAME}.srcs utils_1 imports synth_1]
		file mkdir $utils_dcp_dir
		set project_dcp_file [file join $utils_dcp_dir [file tail $dcp_file]]
		file copy -force $dcp_file $project_dcp_file

		set utils_fileset [get_filesets -quiet utils_1]
		if {$utils_fileset ne ""} {
			catch {add_files -fileset $utils_fileset $project_dcp_file}
		}

		set synth_run [get_runs -quiet synth_1]
		if {$synth_run ne ""} {
			catch {set_property incremental_checkpoint $project_dcp_file $synth_run}
		}

		puts "Restored incremental synthesis DCP: $project_dcp_file"
	}

	 # Process to import xci files to the project, and generate
	 # Out of Context (OOC) output products for each IP that is used in the bd design.
	proc run_ooc_ips {} {
	    
	    set bd_file [FM::find_bd_file]
	    set project_dir [FM::current_vivado_project_dir]
	    if {$bd_file ne "" && [file exists $bd_file]} {
	        update_compile_order -fileset sources_1

	        put "Generate Block Design output products for: $bd_file"
	        set bd_files [get_files -quiet $bd_file]
	        if {$bd_files eq ""} {
	            add_files -fileset sources_1 -norecurse $bd_file
	            set bd_files [get_files -quiet $bd_file]
	        }
	        if {$bd_files ne ""} {
	            generate_target all $bd_files
	            catch {export_ip_user_files -of_objects $bd_files -no_script -sync -force -quiet}
	        }

	        FM::refresh_bd_wrapper

	        set ip_names {}
	        catch {set ip_names [get_ips]}
	        set ooc_threads $FM::OOC_THREADS
	        if {$ooc_threads < 1} {
	            set ooc_threads 1
	        }
	        set active_ooc_runs {}
	        foreach ip $ip_names {
		           ## gets IPs name as they are instantiated, and the corresponding *.xci files are generated.
		           set ip_xci [file join $project_dir ${FM::VIVADO_PROJECT_NAME}.srcs sources_1 bd $FM::DESIGN_NAME ip ${ip} ${ip}.xci]
		           set ip_file ""
		           if {[file exists $ip_xci]} {
		             set ip_file [get_files -quiet -of_objects [get_filesets sources_1] $ip_xci]
		             if {$ip_file eq ""} {
		               set ip_file [get_files -quiet $ip_xci]
		             }
		             if {$ip_file eq ""} {
		               read_ip $ip_xci
		               set ip_file [get_files -quiet $ip_xci]
		             }
		           } else {
		             set ip_file [get_files -quiet -of_objects [get_filesets sources_1] *${ip}.xci]
		           }

		             if {$ip_file eq ""} {
		               catch {common::send_msg_id "FM-002" "WARNING" "Unable to find IP file in project: $ip_xci"}
		               continue
		             }

		             if {[get_property generate_synth_checkpoint $ip_file] == 1 && [get_property is_enabled $ip_file] == 1} {
		           	put "Run OOC (Out of Context) IP for: $ip"
		               if {[get_runs -quiet ${ip}_synth_1] eq ""} {
		                 create_ip_run $ip_file
		               }
		               if {[get_runs -quiet ${ip}_synth_1] eq ""} {
		                 put "Skip OOC for $ip: synthesis checkpoint is already up-to-date"
		                 continue
		               }
		               # it is important to reset the synth_1 before launching the run.
			       reset_run ${ip}_synth_1
			       launch_run -jobs $ooc_threads ${ip}_synth_1
		               lappend active_ooc_runs ${ip}_synth_1
		               if {[llength $active_ooc_runs] >= $ooc_threads} {
		                 foreach active_ooc_run $active_ooc_runs {
		                   wait_on_run $active_ooc_run
		                 }
		                 set active_ooc_runs {}
		               }
		             }
	        }

	        foreach active_ooc_run $active_ooc_runs {
	          wait_on_run $active_ooc_run
	        }
	    }
	}

	proc read_xci {} {
	                set bd_file [FM::find_bd_file]
	                set project_dir [FM::current_vivado_project_dir]
	                if {$bd_file ne ""} {
                        update_compile_order -fileset sources_1
                        set ip_names {}
                        catch {set ip_names [get_ips]}
                        foreach ip $ip_names {
                                set ip_xci [file join $project_dir ${FM::VIVADO_PROJECT_NAME}.srcs sources_1 bd $FM::DESIGN_NAME ip ${ip} ${ip}.xci]
                                if {[file exists $ip_xci]} {
                                        put ${ip}
                                        read_ip $ip_xci
                                 } else {
                                         set ip_file [get_files -quiet -of_objects [get_filesets sources_1] *${ip}.xci]
                                         if {$ip_file ne ""} {
                                                 put ${ip}
                                         }
                                }
                        }
                }
        }



	proc read_user_lib_1 {} {
        	
        	if {[file exists srcs/libs/user_lib_1]} {

        		set vhd_files [glob srcs/libs/user_lib_1/*.vhd]
        		put $vhd_files
        		catch {$vhd_files}
        		foreach vhd $vhd_files {
        	             add_files -norecurse ${vhd}
        	             set_property library user_lib_1 [get_files ${vhd}]
        		}
        	 	update_compile_order -fileset sources_1
        	}

        }


}

set FM::ROOT_PATH [file normalize $::env(ROOT_PATH)]
set FM::VIVADO_PROJECT [FM::normalize_path_from_root $::env(VIVADO_WORK_DIR)]
set FM::VIVADO_PROJECT_NAME $::env(VIVADO_PROJECT_NAME)
set FM::PART_NAME $::env(XILINX_PART)
set FM::BOARD_NAME $::env(BOARD)
set FM::DESIGN_NAME $::env(DESIGN)
set FM::PROJECT_TCL_FILE $::env(PROJECT_TCL_FILE)
set FM::HDL_LANGUAGE $::env(HDL_LANGUAGE) 
set FM::OOC_THREADS $::env(OOC_THREADS)
set FM::AUTO_WRAPPER $::env(AUTO_WRAPPER)



#######################################################################################################


