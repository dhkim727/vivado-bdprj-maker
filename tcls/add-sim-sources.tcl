proc fm_collect_module_names {source_files} {
	set module_names {}

	foreach source_file $source_files {
		set ext [string tolower [file extension $source_file]]
		set fd [open $source_file r]
		set content [read $fd]
		close $fd

		if {$ext eq ".vhd" || $ext eq ".vhdl"} {
			set pattern {(?i)\mentity\s+(\w+)\s+is\M}
		} else {
			set pattern {\mmodule\s+(\w+)}
		}

		foreach {match module_name} [regexp -all -inline $pattern $content] {
			lappend module_names $module_name
		}
	}

	return [lsort -unique $module_names]
}

set sim_source_dirs [list \
	srcs/sim/common \
	srcs/sim/$FM::BOARD_NAME/common \
	srcs/sim/$FM::BOARD_NAME/$FM::DESIGN_NAME \
	srcs/sim/$FM::DESIGN_NAME \
]

set sim_source_extensions [list .v .sv .vhd .vhdl]
set sim_header_extensions [list .vh .svh]
set sim_wave_extensions [list .wcfg]

set sim_files {}
set sim_header_files {}
set sim_wave_files {}
set sim_include_dirs {}

foreach sim_dir $sim_source_dirs {
	foreach sim_file [fm_collect_files_recursive $sim_dir $sim_source_extensions] {
		lappend sim_files $sim_file
	}

	foreach header_file [fm_collect_files_recursive $sim_dir $sim_header_extensions] {
		lappend sim_header_files $header_file
		lappend sim_include_dirs [file dirname $header_file]
	}

	foreach wave_file [fm_collect_files_recursive $sim_dir $sim_wave_extensions] {
		lappend sim_wave_files $wave_file
	}

	set explicit_include_dir $sim_dir/include
	if {[file exists $explicit_include_dir]} {
		lappend sim_include_dirs $explicit_include_dir
	}
}

set sim_files [lsort -unique $sim_files]
set sim_header_files [lsort -unique $sim_header_files]
set sim_wave_files [lsort -unique $sim_wave_files]

if {[llength $sim_files] > 0} {
	set sim_fileset [get_filesets sim_1]

	set existing_sim_files {}
	foreach existing_file [get_files -quiet -all -of_objects $sim_fileset] {
		lappend existing_sim_files [file normalize $existing_file]
	}

	set new_sim_files {}
	foreach sim_file [concat $sim_files $sim_header_files $sim_wave_files] {
		if {[lsearch -exact $existing_sim_files [file normalize $sim_file]] < 0} {
			lappend new_sim_files $sim_file
		}
	}

	if {[llength $new_sim_files] > 0} {
		puts "Adding simulation source files: $new_sim_files"
		add_files -fileset sim_1 -norecurse $new_sim_files
	}

	if {[info exists rtl_include_dirs]} {
		set sim_include_dirs [concat $rtl_include_dirs $sim_include_dirs]
	}
	set sim_include_dirs [lsort -unique $sim_include_dirs]

	if {[llength $sim_include_dirs] > 0} {
		puts "Setting simulation include directories: $sim_include_dirs"
		set_property include_dirs $sim_include_dirs $sim_fileset
	}

	update_compile_order -fileset sim_1

	set sim_module_names [fm_collect_module_names $sim_files]
	set sim_top_candidates {}
	catch {set sim_top_candidates [find_top -fileset sim_1 -return_list]}

	set sim_tops {}
	foreach sim_top_candidate $sim_top_candidates {
		if {[lsearch -exact $sim_module_names $sim_top_candidate] >= 0} {
			lappend sim_tops $sim_top_candidate
		}
	}

	if {[llength $sim_tops] == 0} {
		set sim_tops $sim_module_names
	}

	if {[llength $sim_tops] > 0} {
		set sim_top [lindex $sim_tops 0]
		if {[llength $sim_tops] > 1} {
			catch {common::send_msg_id "FM-015" "WARNING" "Multiple simulation top candidates found: $sim_tops. Using: $sim_top"}
		}
		puts "Setting sim_1 top module: $sim_top"
		set_property top $sim_top $sim_fileset
		set_property top_lib xil_defaultlib $sim_fileset
		update_compile_order -fileset sim_1
	}
}
