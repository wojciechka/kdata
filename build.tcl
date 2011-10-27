set fh [open kdata-all.tcl w]
foreach f {kdata.tcl kd_java.tcl kd_python.tcl kd_tcl.tcl} {
    set sfh [open kdata/$f r]
    puts $fh [read $sfh]
    close $sfh
}
close $fh

exit 0
