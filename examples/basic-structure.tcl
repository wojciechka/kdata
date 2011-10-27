#!/usr/bin/env tclkit

cd [file dirname [info script]]
set dir [file rootname [file tail [info script]]]
if {![file exists ../kdata-all.tcl]} {
    puts stderr "Please run build.tcl before running tests."
    exit 1
}

source ../kdata-all.tcl

catch {file delete -force $dir}
file mkdir $dir

kdata::initialize -datafile [file join $dir kdata.dat]
kdata::language tcl -output-file [file join $dir kdataexample.tcl] -namespace kdataexample
kdata::language python -output-file [file join $dir kdataexample.py]
kdata::language java -output-file [file join $dir KdataExample.java] -class KdataExample

kdata::enum sample.enum {
    zero
    one
    two
}

kdata::structure sample.data {
    int64 longValue
    int32 intValue
    int16 shortValue
    string textAsUTF
    bytearray binaryData
}

kdata::structure sample.datalist {
    list sample.data sampleDataList
}

kdata::commit
