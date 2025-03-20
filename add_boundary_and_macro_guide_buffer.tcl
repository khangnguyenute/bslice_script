## Add buffer into signal ports, except clk port
set signal_ports [get_ports -phy -f "port_type==signal && full_name!~clk"]
set piso_cells [get_cells -phy *_UPF_ISO]
set piso_nets [get_nets -phy -o [get_pins -phy -o $piso_cells -f "direction==out"]]
set piso_ports [get_ports -phy -o $piso_nets -f "port_type==signal"]
set ignored_piso_ports [remove_from_collection $signal_ports $piso_ports]
if {[sizeof_collection $ignored_piso_ports] > 0} {
	set buf_port_signal [add_buffer $ignored_piso_ports -lib_cell saed32_lvt|saed32_lvt_std/NBUFFX4_LVT  -new_cell_names buf_port_signal -new_net_names buf_port_signal]
	magnet_placement -cell $buf_port_signal $ignored_piso_ports -move_legalize_only
}

## Add inverter into clk port
set clk_port [get_ports -phy *clk*]                                                                                                                                                                  
set inv_port_signal [add_buffer $clk_port -inverter_pair -lib_cell saed32_lvt|saed32_lvt_std/INVX4_LVT -new_cell_names {inv_port_signal inv_port_signal} -new_net_names {inv_port_signal inv_port_signal}]
magnet_placement -cell $inv_port_signal $clk_port -move_legalize_only

legalize_placement

##Set placement status buffer and inverter being added
set_fixed_objects $inv_port_signal 
set_fixed_objects $buf_port_signal

### add buffer into pins of macros
if {[sizeof_collection [get_cells -phy -f "design_type==macro" -q]]>0} {
	set macro_cells [get_cells -phy -f "design_type==macro"]
	set pin_signals [get_pins -phy -o $macro_cells -f "port_type==signal&&direction==out" -q]
	
	if {[sizeof_collection $pin_signals]>0} {
		set buf_pin_signals [add_buffer $pin_signals -lib_cell saed32_lvt|saed32_lvt_std/NBUFFX4_LVT  -new_cell_names buf_pin_signal -new_net_names buf_pin_signal]
		magnet_placement -cell $buf_pin_signals $pin_signals -move_legalize_only
		set_attribute $buf_pin_signals -name physical_status -value legalize_only
	}
}