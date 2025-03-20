set flag 0

while {$flag == 0} {
	set slack [get_attribute [get_timing_paths] slack]

	while {$slack < 0} {
		report_timing > path_to_fix.rpt
		set command {egrep "Startpoint|Endpoint" path_to_fix.rpt | awk 'NR%2{printf "handle_fix_path %s ", $2; next} {print $2}'} 
		exec sh -c $command > path_to_fix.tcl
		source path_to_fix.tcl
		set slack [get_attribute [get_timing_paths] slack]
	}

	legalize_placement
	route_eco
	route_detail
	
	set slack [get_attribute [get_timing_paths] slack]
	if {$slack > 0} {
		set flag 1
	}
}
