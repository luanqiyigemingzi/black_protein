source "D:/Anlogic/TD_6.2.1_Engineer_6.2.168.116/cw/atpl/templa.tcl"
set fd [open "D:/Anlogic/TD_6.2.1_Engineer_6.2.168.116/cw/atpl/cwc.atpl" r]
set tmpl [read $fd]
close $fd
set parser [::tmpl_parser::tmpl_parser $tmpl]

set ComponentName        auto_created_cwc1
set bus_num              2
set cwc_ctrl_len         76
set cwc_bus_ctrl_len     56
set bus_din_num          16
set ram_len              16
set input_pipe_num       0
set output_pipe_num      0
set depth                1024
set capture_ctrl_exist   0
set bus_width            { 8,8 };
set bus_din_pos          { 0,8 };
set bus_ctrl_pos         { 0,28 };
set fp [open "cw/auto_created_cwc1/auto_created_cwc1_watcherInst.sv" w+]
puts $fp [eval $parser]
close $fp
