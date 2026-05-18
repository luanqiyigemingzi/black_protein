source "D:/Anlogic/TD_6.2.1_Engineer_6.2.168.116/cw/atpl/templa.tcl"
set fd [open "D:/Anlogic/TD_6.2.1_Engineer_6.2.168.116/cw/atpl/cwc_ip.atpl" r]
set tmpl [read $fd]
close $fd
set parser [::tmpl_parser::tmpl_parser $tmpl]

set ComponentName        ChipWatcher_e16b8e4ff8cf
set bus_num              1
set depth                1024
set ram_len              12
set input_pipe_num       2
set output_pipe_num      0
set capture_ctrl_exist   1
set trig_bus_num         1
set trig_bus_din_num     12
set trig_bus_ctrl_len    40
set trig_ctrl_len        102
set trig_bus_width       { 12 };
set trig_bus_din_pos     { 0 };
set trig_bus_ctrl_pos    { 0 };
set bus_size             {  12 }
set data_enable          { probe0 }
set trig_enable          { probe0 }
set fp [open "cw/ChipWatcher_e16b8e4ff8cf/ChipWatcher_e16b8e4ff8cf_watcherInst.sv" w+]
puts $fp [eval $parser]
close $fp
