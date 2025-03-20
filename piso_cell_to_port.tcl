if {[sizeof_collection [get_cells -phy *_UPF_ISO -q]]>0} {
  set piso_cells [get_cells -phy *_UPF_ISO]
  set piso_nets [get_nets -phy -o [get_pins -phy -o $piso_cells -f "direction==out"]]                                                                                    
  set piso_ports [get_ports -phy -o $piso_nets -q]

  if {[sizeof_collection $piso_ports] >0 } { 
           magnet_placement -cells $piso_cells $piso_ports 
           set_attribute $piso_cells -name physical_status -value legalize_only
  }
}