#
# (c) 2004-2011 Wojciech Kocjan
# Licensed under BSD-style license
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#

namespace eval kdata {}

if {![info exists kdata::kdataIdx]} {
    set kdata::kdataIdx 0
}

set kdata::configVariables [list \
    structureHistory structureId structureData \
    enumHistory \
    ]

proc kdata::initialize {args} {
    variable config
    array set default {
        -datafile                       kdata.dat
    }
    foreach {n v} $args {
        if {![info exists default($n)]} {
            set ei "Unknown parameter: $n"
            return -code error -errorinfo $ei $ei
        }
        set config($n) $v
    }
    foreach {n v} [array get default] {
        if {![info exists config($n)]} {
            set config($n) $v
        }
    }
    dataLoad
    initParser
}

proc kdata::dataLoad {} {
    variable config
    variable configVariables
    foreach c $configVariables {variable $c}
    if {[file exists $config(-datafile)]} {
        set fh [open $config(-datafile) r]
        fconfigure $fh -translation lf -encoding identity
        set fc [read $fh]
        close $fh
        
        foreach {n v} $fc {
            if {[lsearch -exact $configVariables $n]<0} {continue}
            array set $n {}
            array unset $n *
            array set $n $v
        }
    }
    if {![info exists structureData(lastId)]} {
        set structureData(lastId) 0
    }
}

proc kdata::dataSave {} {
    variable config
    variable configVariables

    set data [list]
    foreach v $configVariables {
        variable $v
        set agd [list]
        foreach vn [lsort [array names $v]] {
            set vv [set ${v}($vn)]
            lappend agd $vn $vv
        }
        lappend data $v $agd
    }

    if {[file exists $config(-datafile)]} {
        set fh [open $config(-datafile) r]
        fconfigure $fh -translation lf -encoding identity
        set fhdata [read $fh]
        close $fh
        if {[string equal $data $fhdata]} {
            return
        }
        
        set del $config(-datafile)_
        catch {file delete -force $del}
        file rename $config(-datafile) $del
    }

    set fh [open $config(-datafile) w]
    fconfigure $fh -translation lf -encoding identity
    puts -nonewline $fh $data
    close $fh

    if {[info exists del]} {
        file delete $del
    }
}

proc kdata::initParser {} {
    if {![namespace exists ::kdata::parser]} {
        namespace eval ::kdata::parser {
            # mandatory elements: type name defaultValue
            proc _init {} {
                variable d
            }
            proc int64 {name {default 0}} {
                uplevel 2 [::list lappend elements [::list int64 $name $default]]
            }
            proc int32 {name {default 0}} {
                uplevel 2 [::list lappend elements [::list int32 $name $default]]
            }
            proc int16 {name {default 0}} {
                uplevel 2 [::list lappend elements [::list int16 $name $default]]
            }
            proc char {name {default 0}} {
                uplevel 2 [::list lappend elements [::list char $name $default]]
            }
            proc byte {name {default 0}} {
                uplevel 2 [::list lappend elements [::list byte $name $default]]
            }
            proc string {name {default ""}} {
                uplevel 2 [::list lappend elements [::list string $name $default]]
            }
            proc bytearray {name {default ""}} {
                uplevel 2 [::list lappend elements [::list bytearray $name $default]]
            }
            proc array {type name {default ""}} {
                uplevel 2 [::list lappend elements [::list array $name $default $type]]
            }
            proc list {type name {default ""}} {
                uplevel 2 [::list lappend elements [::list list $name $default $type]]
            }
            proc element {type name {default ""}} {
                uplevel 2 [::list lappend elements [::list element $name $default $type]]
            }
        }
    }
}

proc kdata::language {language args} {
    variable kdataIdx
    variable kdataList

    set idx [incr kdataIdx]
    set var ::kdata::kdata$idx
    
    lappend kdataList $var

    array set i {
        -output-file                    ""

        -parser-prefix                  parse
        -builder-prefix                 build
        -structcall-prefix              structcall
        -multiplexer-command            multiplex

        -create-parsers                 true
        -create-builders                true
        -create-datatypes               true
        -create-structcall              true
        -create-multiplexer             true
        -create-enums                   true

        -create-comments                true
        -debug                          false
        -verbose                        false
        -break-pages                    false
    }

    package require kdata::language::$language

    set ns ::kdata::$language
    array set i [set ${ns}::default]
    foreach {n v} $args {
        if {![info exists i($n)]} {
            set ei "Unknown parameter: $n"
            return -code error -errorinfo $ei $ei
        }
        set i($n) $v
    }
    upvar #0 $var va
    set va(language) $language
    set va(ns) $ns
    array set va [array get i]
    return $var
}

proc kdata::enum {name names} {
    variable enumHistory

    set maxValue 0
    if {[info exists enumHistory($name)]} {
        foreach revision $enumHistory($name) {
            foreach {n v} $revision {
                if {$v >= $maxValue} {
                    set maxValue $v
                }
                set value($n) $v
            }
        }
    }

    set last [list]
    foreach n $names {
        if {[llength $n] > 1} {
            set nvalue [lindex $n 1]
            set n [lindex $n 0]
            if {[info exists value($n)] && ($nvalue != $value($n))} {
                error "Invalid enum value $nvalue for $n - previous is $value($n)"
            }
            set value($n) $nvalue
        }
        if {[info exists value($n)]} {
            lappend last $n $value($n)
        }  else  {
            lappend last $n $maxValue
            incr maxValue
        }
    }

    if {(![info exists enumHistory($name)]) ||
        ([lindex $enumHistory($name) end] != $last)} {
        lappend enumHistory($name) $last
    }
}

proc kdata::structure {name description} {
    variable structureId
    variable structureName
    variable structureData
    variable structureHistory
    set elements [list]
    namespace eval ::kdata::parser {_init}
    if {[catch {
        namespace eval ::kdata::parser $description
    } rc]} {
        return -code error -errorinfo $::errorInfo -errorcode $::errorCode
    }

    if {![info exists structureId($name)]} {
        set id [incr structureData(lastId)]
        set structureId($name) $id
    }
    set id $structureId($name)
    set structureName($id) $name

    if {![info exists structureHistory($id)]} {
        set structureHistory($id) [list]
    }
    set last [lindex $structureHistory($id) end]
    
    # TODO: compare in a better way
    if {($last != $elements) || ([llength $structureHistory($id)] == 0)} {
        lappend structureHistory($id) $elements
    }
}


# there really shouldn't be more than 64-levels deep nests
proc kdata::checkStructureDep {id {level 64}} {
    variable structureName
    variable structureStruct
    variable structureId
    incr level -1
    if {$level<0} {return 0}
    set current [lindex $structureStruct($id) end]
    set histsize [llength $structureStruct($id)]
    set histpos 0
    
    set current $structureStruct($id)
    set structureStruct($id) [list]

    foreach {hp current} $current {
        incr histpos

        set currentOk true
        foreach element $current {
            set type [lindex $element 0]
            set name [lindex $element 1]
            switch -- $type {
                array - element - list {
                    if {![checkStructureDep [lindex $element 3] $level]} {
                        if {$histpos == $histsize} {
                            return 0
                        }  else  {
                            set currentOk false
                        }
                    }
                }
            }
        }
        if {$currentOk} {
            lappend structureStruct($id) $hp $current
        }
    }
    return 1
}

proc kdata::commit {} {
    variable structureId
    variable structureName
    variable structureHistory
    variable structureStruct
    variable enumHistory
    
    variable kdataList
    
    # convert element/array elements to IDs
    foreach id [array names structureHistory] {
        set hstruct [list]
        set histsize [llength $structureHistory($id)]
        set histpos 0
        set structureStruct($id) [list]
        set elementOk true
        foreach element $structureHistory($id) {
            incr histpos
            set current [list]
            foreach element $element {
                set type [lindex $element 0]
                set name [lindex $element 1]
                set structure [lindex $element 3]
                if {($type == "element") && [isPrimitive $structure]} {
                    set ei "Cannot use $structure as element"
                    return -code error -errorinfo $ei $ei
                }
                if {(($type == "array") || ($type == "list")) && [isPrimitive $structure]} {
                    if {![isPrimitiveListSupported $structure]} {
                        set ei "Cannot use $structure as primitive list"
                        return -code error -errorinfo $ei $ei
                    }
                    set type "primitivelist"
                    set element [lreplace $element 0 0 $type]
                }

                if {($type == "array") || ($type == "list") || ($type == "element")} {
                    set thisStructure $structureName($id)
                    if {![info exists structureId($structure)]} {
                        if {$histpos == $histsize} {
                            # if this is the most recent entry, then
                            # we shouldn't allow non-existing structures
                            set ei "Unknown structure \"$structure\" in \"$thisStructure\""
                            return -code error -errorinfo $ei $ei
                        }  else  {
                            # otherwise, throw away reading historic structures
                            set elementOk false
                        }
                    }
                    if {$elementOk} {
                        set element [lreplace $element 3 3 $structureId($structure)]
                    }
                }
                if {$elementOk} {
                    lappend current $element
                }
            }
            lappend structureStruct($id) $histpos $current
        }
    }

    # dependency loop check
    foreach id [array names structureHistory] {
        if {![checkStructureDep $id]} {
            set thisStructure $structureName($id)
            set ei "Nesting too deep in \"$thisStructure\""
            return -code error -errorinfo $ei $ei
        }
    }
    
    # reverse structureStruct from newest to latest (shouls speed up version matching)
    # since upgrading should cause mainly newest versions to be sent/received
    
    foreach id [array names structureHistory] {
        set current $structureStruct($id)
        set structureStruct($id) [list]
        foreach {histpos current} $current {
            set structureStruct($id) [linsert $structureStruct($id) 0 $histpos $current]
        }
    }
    
    # now that all neccessary data structures checking is complete,
    # save the data file and create each language's definition
    dataSave
    
    foreach kdataVar $kdataList {
        upvar #0 $kdataVar kd
        set code ""
        
        append code [$kd(ns)::code_begin $kdataVar]
        
        # create datatypes
        if {$kd(-create-datatypes)} {
        }
        
        # create parsers
        if {$kd(-create-parsers)} {
            foreach id [array names structureStruct] {
                set name $structureName($id)
                # begin a parser
                append code [$kd(ns)::parser_begin $kdataVar $name]
                
                set finalElements [list]
                foreach element [lindex $structureStruct($id) 1] {
                    lappend finalElements [list [lindex $element 1] [lindex $element 2]]
                }

                foreach {version elements} $structureStruct($id) {
                    append code [$kd(ns)::parser_version_begin $kdataVar $version]
                    
                    # store all version's elements to match them against ones
                    # actually needed

                    array set matchElement {}
                    array unset matchElement *
                    
                    foreach element $elements {
                        set matchElement([lindex $element 1]) [lindex $element 2]
                        append code [$kd(ns)::parser_element $kdataVar \
                            [lindex $element 0] \
                            [lindex $element 1] \
                            [lindex $element 2] \
                            [lrange $element 3 end]]
                    }
                    
                    set existingElements [list]
                    set nonexistingElements [list]
                    set allElements [list]
                    foreach element $finalElements {
                        if {[info exists matchElement([lindex $element 0])]} {
                            lappend existingElements $element
                            lappend allElements [concat $element [list true]]
                        }  else  {
                            lappend nonexistingElements $element
                            lappend allElements [concat $element [list false]]
                        }
                    }
                    
                    append code [$kd(ns)::parser_version_end $kdataVar $allElements $existingElements $nonexistingElements]
                }
                append code [$kd(ns)::parser_end $kdataVar]
                if {$kd(-break-pages)} { append code \x0c }
            }
        }
        

        # create builders
        if {$kd(-create-builders)} {
            foreach id [array names structureStruct] {
                set name $structureName($id)
                set version [lindex $structureStruct($id) 0]
                set elements [lindex $structureStruct($id) 1]
                
                append code [$kd(ns)::builder_begin $kdataVar $name $version]
                foreach element $elements {
                    append code [$kd(ns)::builder_element $kdataVar \
                        [lindex $element 0] \
                        [lindex $element 1] \
                        [lindex $element 2] \
                        [lrange $element 3 end]]
                }
                append code [$kd(ns)::builder_end $kdataVar]
            }
        }
        
        # create datatypes
        if {$kd(-create-datatypes)} {
            foreach id [array names structureStruct] {
                set name $structureName($id)
                set version [lindex $structureStruct($id) 0]
                set elements [lindex $structureStruct($id) 1]
                
                append code [$kd(ns)::datatype_begin $kdataVar $name]
                foreach element $elements {
                    append code [$kd(ns)::datatype_element $kdataVar \
                        [lindex $element 0] \
                        [lindex $element 1] \
                        [lindex $element 2] \
                        [lrange $element 3 end]]
                }
                append code [$kd(ns)::datatype_end $kdataVar]
            }
        }
        
        # create struct call
        if {$kd(-create-structcall)} {
            foreach id [array names structureStruct] {
                set name $structureName($id)
                set version [lindex $structureStruct($id) 0]
                set elements [lindex $structureStruct($id) 1]
                
                append code [$kd(ns)::structcall_begin $kdataVar $name]
                foreach element $elements {
                    append code [$kd(ns)::structcall_element $kdataVar \
                        [lindex $element 0] \
                        [lindex $element 1] \
                        [lindex $element 2] \
                        [lrange $element 3 end]]
                }
                append code [$kd(ns)::structcall_end $kdataVar]
            }
        }
        
        # create multiplexer
        if {$kd(-create-multiplexer)} {
            append code [$kd(ns)::multiplexer_code_begin $kdataVar]
            foreach id [array names structureStruct] {
                set name $structureName($id)
                set version [lindex $structureStruct($id) 0]
                set elements [lindex $structureStruct($id) 1]
                
                append code [$kd(ns)::multiplexer_begin $kdataVar $name]
                foreach element $elements {
                    append code [$kd(ns)::multiplexer_element $kdataVar \
                        [lindex $element 0] \
                        [lindex $element 1] \
                        [lindex $element 2] \
                        [lrange $element 3 end]]
                }
                append code [$kd(ns)::multiplexer_end $kdataVar]
            }
            append code [$kd(ns)::multiplexer_code_end $kdataVar]
        }
        
        # create enums
        if {$kd(-create-enums)} {
            foreach enumName [lsort [array names enumHistory]] {
                append code [$kd(ns)::enum_begin $kdataVar $enumName]
                foreach {enumVKey enumValue} [lindex $enumHistory($enumName) end] {
                    append code [$kd(ns)::enum_value $kdataVar $enumName $enumVKey $enumValue]
                }
                append code [$kd(ns)::enum_end $kdataVar $enumName]
            }
        }
        
        append code [$kd(ns)::code_end $kdataVar]
        
        if {$kd(-output-file)!=""} {
            set fh [open $kd(-output-file) w]
            puts $fh $code
            close $fh
        }
    }
}

proc kdata::buildTitleName {name} {
    set rc ""
    foreach c [split $name .] {
	append rc [string totitle $c]
    }
    return $rc
}

proc kdata::buildUpperName {name} {
    return [string toupper [join [split $name .] _]]
}

proc kdata::getNameById {id} {
    variable structureName
    return $structureName($id)
}

proc kdata::getIdByName {name} {
    variable structureId
    return $structureId($name)
}

proc kdata::isPrimitive {type} {
    if {[lsearch -exact {int64 int32 int16 char byte string bytearray} $type] >= 0} {
        return 1
    }  else  {
        return 0
    }
}

proc kdata::isPrimitiveListSupported {type} {
    if {[lsearch -exact {int64 int32 int16 byte} $type] >= 0} {
        return 1
    }  else  {
        return 0
    }
}

package provide kdata 1.0

