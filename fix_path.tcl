proc handle_size_cell {startpoint endpoint} {
  report_timing -from $startpoint -to $endpoint > timing.rpt
  set size_cell {awk '($2 ~ /_(RVT|HVT)/ && $3 > 0.05) {print "size_cell ", $1, $2}' timing.rpt | awk '{gsub(/RVT|HVT/, "LVT"); gsub(/[()]/, ""); print}' | awk -F'/' '{OFS="/"; $NF=$NF; sub("/[^/]* ", " "); print}' | sort | uniq > size_cell_list.tcl}
  exec csh -c $size_cell
  set file_size [file size size_cell_list.tcl]
  
  #Handle until no HVT, RVT cells remain or slack > 0
  while {$file_size != 0} {
    set flag 0
    set file_id [open "size_cell_list.tcl" r]
    while {[gets $file_id line] >= 0} {
      # Source the line of code
      eval $line

      set slack [get_attribute [get_timing_paths -from $startpoint -to $endpoint] slack]
      if {$slack > 0} {
      	set flag 1
      	break
      }
    }
    close $file_id
  
    if {$flag == 1} return
    report_timing -from $startpoint -to $endpoint > timing.rpt
    exec csh -c $size_cell
    set file_size [file size size_cell_list.tcl]
  }
}

proc handle_inv_add {startpoint endpoint} {
  set added_net [get_nets -phy -o $endpoint/CLK -f {full_name =~ "*inv_fix_load*"} -q]

  # Check if the path is added invx0
  if {[sizeof_collection $added_net] == 0} {
    #Add the inv
    add_buffer $endpoint/CLK -inverter_pair -lib_cell saed32_lvt|saed32_lvt_std/INVX0_LVT -new_cell_names {inv_fix_drive inv_fix_load} -new_net_names {inv_fix_drive inv_fix_load}

    #Check slack
    set slack [get_attribute [get_timing_paths -from $startpoint -to $endpoint] slack]
    if {$slack >= 0} return
  }

  #Get load inv, then upsizing load inv if slack is violated
  set load_inv [get_cells -phy -o [get_nets -phy -o $endpoint/CLK -f {full_name =~ "*inv_fix_load*"}] -f {ref_name =~ "*INV*"}] 
  if {[string match "INVX0*" [get_attribute $load_inv ref_name]]} {
    size_cell $load_inv INVX2_LVT

    #Check slack
    set slack [get_attribute [get_timing_paths -from $startpoint -to $endpoint] slack]
    if {$slack >= 0} return
  }
  if {[string match "INVX2*" [get_attribute $load_inv ref_name]]} {
    size_cell $load_inv INVX4_LVT

    #Check slack
    set slack [get_attribute [get_timing_paths -from $startpoint -to $endpoint] slack]
    if {$slack >= 0} return
  }
  if {[string match "INVX4*" [get_attribute $load_inv ref_name]]} {
    size_cell $load_inv INVX8_LVT

    #Check slack
    set slack [get_attribute [get_timing_paths -from $startpoint -to $endpoint] slack]
    if {$slack >= 0} return
  }
  size_cell $load_inv INVX16_LVT
}

proc handle_fix_slack {startpoint endpoint} {
  #Check slack
  set slack [get_attribute [get_timing_paths -from $startpoint -to $endpoint] slack]
  if {$slack >= 0} return

  #Size cell
  handle_size_cell $startpoint $endpoint
  #Check slack
  set slack [get_attribute [get_timing_paths -from $startpoint -to $endpoint] slack]
  if {$slack >= 0} return
  
  #Add inv
  handle_inv_add $startpoint $endpoint
}

set index 0

proc handle_fix_path {startpoint endpoint} {
  global index
  
  #fix curent path 
  handle_fix_slack $startpoint $endpoint

  incr index
  set file_name "timing${index}"

  report_timing -from $endpoint -max_paths 1000 -slack_lesser_than 0 > $file_name.rpt

  #check if there are any more paths
  set is_violated_path 0
  set file_id [open "${file_name}.rpt" r]

  while {[gets $file_id line] != -1} {
    if {[string match "*Startpoint*" $line]} {
    	set is_violated_path 1
    	break
    }
  }
  close $file_id
  
  # ignore the below steps if there are no more paths
  if {$is_violated_path == 0} {
	sh rm -rf $file_name.rpt
  	return
  }

  #use recursion to handle if there are any paths left
  set list_cell_param "awk '/Startpoint:/ {start=\$2} /Endpoint:/ {end=\$2; print \"handle_fix_path\", start, end}' \$file_name.rpt > \$file_name.tcl"
  setenv file_name $file_name
  exec csh -c $list_cell_param
  sh rm -rf $file_name.rpt
  source $file_name.tcl
  sh rm -rf $file_name.tcl
}
