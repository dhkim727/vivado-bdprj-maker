##################################################################################
# DESCRIPTION:
# Add standalone XCI IP sources before adding RTL and sourcing a block-design Tcl.
#
# This is required when project RTL instantiates an IP module generated from an
# XCI file, for example:
#   fir_2dec fir_2dec_inst (...)
#
# Keep each XCI and its local data files, such as *.coe, in the same IP-specific
# directory under srcs/xci/<BOARD>/<DESIGN>/<ip_name>/ unless the XCI intentionally
# references another relative path.
##################################################################################

proc fm_collect_xci_files_recursive {root_dir} {
      set collected_files {}

      if {![file exists $root_dir]} {
            return $collected_files
      }

      foreach entry [glob -nocomplain -directory $root_dir *] {
            if {[file isdirectory $entry]} {
                  set child_files [fm_collect_xci_files_recursive $entry]
                  foreach child_file $child_files {
                        lappend collected_files $child_file
                  }
            } elseif {[string tolower [file extension $entry]] eq ".xci"} {
                  lappend collected_files $entry
            }
      }

      return [lsort -unique $collected_files]
}

set xci_files [fm_collect_xci_files_recursive srcs/xci/$FM::BOARD_NAME/$FM::DESIGN_NAME]

foreach xci_file $xci_files {
      puts "Reading standalone XCI source: $xci_file"
      set old_pwd [pwd]
      set xci_abs_file [file normalize $xci_file]
      set xci_name [file rootname [file tail $xci_abs_file]]
      set project_dir [FM::current_vivado_project_dir]
      set legacy_project_xci_file [file normalize [file join $project_dir ${FM::VIVADO_PROJECT_NAME}.srcs sources_1 ip $xci_name [file tail $xci_abs_file]]]

      set legacy_ip_file [get_files -quiet $legacy_project_xci_file]
      if {$legacy_ip_file ne ""} {
            puts "Removing legacy project-local XCI copy: $legacy_project_xci_file"
            remove_files $legacy_ip_file
      }

      FM::rewrite_generated_output_paths_in_file $xci_abs_file

      set xci_ip_file [get_files -quiet $xci_abs_file]
      if {$xci_ip_file eq ""} {
            read_ip $xci_abs_file
            set xci_ip_file [get_files -quiet $xci_abs_file]
      }

      if {$xci_ip_file ne ""} {
            puts "Generating standalone XCI output products: $xci_abs_file"
            generate_target all $xci_ip_file
            catch {export_ip_user_files -of_objects $xci_ip_file -no_script -sync -force -quiet}
      } else {
            catch {common::send_msg_id "FM-003" "WARNING" "Unable to find standalone XCI in project after read_ip: $xci_abs_file"}
      }

      cd $old_pwd
}

if {[llength $xci_files] > 0} {
      update_compile_order -fileset sources_1
}

##################################################################################