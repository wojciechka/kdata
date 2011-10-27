#
# (c) 2004-2011 Wojciech Kocjan
# Licensed under BSD-style license
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#

namespace eval kdata::tcl {}

set kdata::tcl::default [list \
    -package                            "" \
    -namespace                          "" \
    -data-description-prefix            fields \
    -receiver-namespace                 "" \
    -create-prefix                      create \
    -idx-prefix                         idx \
    ]

proc kdata::tcl::code_begin {var} {
    upvar #0 $var v
    set rc ""
    append rc "#" \n
    append rc "# CODE GENERATED USING kdata::language::tcl 1.0" \n
    append rc "#" \n
    append rc "# DO NOT EDIT BY HAND" \n
    append rc "#" \n
    
    append rc "" \n

    if {$v(-namespace) != ""} {
        append rc "namespace eval $v(-namespace) {}" \n\n
    }
    return $rc
}

proc kdata::tcl::code_end {var} {
    upvar #0 $var v
    set rc ""
    if {$v(-package) != ""} {
        append rc "package provide $v(-package) 1.0" \n
    }
    return $rc
}


# parser
proc kdata::tcl::parser_begin {var name} {
    upvar #0 $var v
    set v(_versionfirst) true
    set v(_name) $name
    set rc ""
    
    set procName $v(-namespace)::$v(-parser-prefix)[kdata::buildTitleName $name]
    
    if {$v(-create-comments)} {
        append rc "#----------------------------------------------------------------------" \n
        append rc "#" \n
        append rc "# $procName --" \n
        append rc "#" \n
        append rc "#\tParse a \"$name\" binary structure and return it as a dictionary." \n
        append rc "#\tThis function throws an error if data is corrupted or incomplete." \n
        append rc "#" \n
        append rc "# Parameters:" \n
        append rc "#" \n
        append rc "#\tdata -- binary data to be parsed." \n
        append rc "#" \n
        append rc "# Results:" \n
        append rc "#" \n
        append rc "#\tData parsed and returned as a dictionary." \n
        append rc "#" \n
        append rc "# Side effects:" \n
        append rc "#" \n
        append rc "#\tNone." \n
        append rc "#" \n
        append rc "#----------------------------------------------------------------------" \n
        append rc \n
    }
    append rc "proc [list $procName] \{data\} \{" \n
    if {$v(-verbose)} {
        append rc \n "    # getting the package version number." \n
    }
    append rc "    if \{!\[binary scan \$data Sa* version data\]\} \{" \n
    append rc "        set version 0" \n
    append rc "    \}" \n
    return $rc
}

proc kdata::tcl::parser_version_begin {var version} {
    upvar #0 $var v
    set rc ""
    if {$v(_versionfirst)} {
        set v(_versionfirst) false
        append rc "    if \{\$version == $version\} \{" \n
    }  else  {
        append rc "    \}  elseif \{\$version == $version\} \{" \n
    }
    return $rc
}

proc kdata::tcl::parser_element {var type name default parameters} {
    upvar #0 $var v
    set rc ""
    set throwError {return -code error -errorcode \[list KDATA EOF\] -errorinfo "Error while parsing \\\"[list $name]\\\"" "Error while parsing \\\"[list $name]\\\""}

    array set scantype {int64 W int32 I int16 S byte c}
    set ln "[list TMP$name]"
    if {$v(-verbose)} {
        append rc \n "        # trying to fetch '$name' element ($type)" \n
    }
    switch -- $type {
        int64 {
            append rc "        if \{\[binary scan \$data Wa* $ln data\]!=2\} \{" \n
            append rc "            " [subst $throwError] \n
            append rc "        \}" \n
        }
        int64 - int32 - int16 - byte {
            set st $scantype($type)
            append rc "        if \{\[binary scan \$data ${st}a* $ln data\]!=2\} \{" \n
            append rc "            " [subst $throwError] \n
            append rc "        \}" \n
        }
        char {
            append rc "        if \{\[binary scan \$data Sa* $ln data\]!=2\} \{" \n
            append rc "            " [subst $throwError] \n
            append rc "        \}" \n
            append rc "        set $ln \[format \"%c\" $ln\]" \n
        }
        string {
            append rc "        if \{\[binary scan \$data Sa* datasize data\]!=2\} \{" \n
            append rc "            " [subst $throwError] \n
            append rc "        \}" \n
            append rc "        if \{\[binary scan \$data a\$\{datasize\}a* $ln data\]!=2\} \{" \n
            append rc "            " [subst $throwError] \n
            append rc "        \}" \n
            append rc "        set $ln \[encoding convertfrom utf-8 \$$ln\]" \n
        }
        bytearray {
            append rc "        if \{\[binary scan \$data Ia* datasize data\]!=2\} \{" \n
            append rc "            " [subst $throwError] \n
            append rc "        \}" \n
            append rc "        if \{\[binary scan \$data a\$\{datasize\}a* $ln data\]!=2\} \{" \n
            append rc "            " [subst $throwError] \n
            append rc "        \}" \n
        }
        element {
            set elname [kdata::buildTitleName [kdata::getNameById [lindex $parameters 0]]]
            append rc "        if \{\[binary scan \$data Ia* datasize data\]!=2\} \{" \n
            append rc "            " [subst $throwError] \n
            append rc "        \}" \n
            append rc "        if \{\[binary scan \$data a\$\{datasize\}a* elemdata data\]!=2\} \{" \n
            append rc "            " [subst $throwError] \n
            append rc "        \}" \n
            append rc "        set $ln \[$v(-parser-prefix)${elname} \$elemdata\]" \n
        }
        array - list {
            set elname [kdata::buildTitleName [kdata::getNameById [lindex $parameters 0]]]
            append rc "        set $ln \[list\]" \n
            append rc "        if \{\[binary scan \$data Ia* readsize data\]!=2\} \{" \n
            append rc "            " [subst $throwError] \n
            append rc "        \}" \n
            append rc "        for \{set i 0\} \{\$i < \$readsize\} \{incr i\} \{" \n
            append rc "            if \{\[binary scan \$data Ia* datasize data\]!=2\} \{" \n
            append rc "                " [subst $throwError] \n
            append rc "            \}" \n
            append rc "            if \{\[binary scan \$data a\$\{datasize\}a* elemdata data\]!=2\} \{" \n
            append rc "                " [subst $throwError] \n
            append rc "            \}" \n
            append rc "            lappend $ln \[$v(-parser-prefix)${elname} \$elemdata\]" \n
            append rc "        \}" \n
        }
        primitivelist {
            append rc "        set $ln \[list\]" \n
            append rc "        if \{\[binary scan \$data Ia* readsize data\]!=2\} \{" \n
            append rc "            " [subst $throwError] \n
            append rc "        \}" \n
            switch -- [lindex $parameters 0] {
                int64 - int32 - int16 - byte {
                    set st $scantype([lindex $parameters 0])
                    append rc "            if \{\[binary scan \$data ${st}\$\{readsize\}a* $ln data\]!=2\} \{" \n
                    append rc "                " [subst $throwError] \n
                    append rc "            \}" \n
                }
                default {
                    set ei "Unknown primitive list datatype \"[lindex $parameters 0]\""
                    return -code error -errorcode [list KDATAPARSER UNKNOWNDATATYPE] -errorinfo $ei $ei
                }
            }
        }
        default {
            set ei "Unknown datatype \"$type\""
            return -code error -errorcode [list KDATAPARSER UNKNOWNDATATYPE] -errorinfo $ei $ei
        }
    }
    return $rc
}

proc kdata::tcl::parser_version_end {var all existing nonexisting} {
    upvar #0 $var v
    set rc ""
    # return data
    append rc "        return \[dict create"
    foreach e $all {
        foreach {name default exist} $e break
        #append rc "$name: $exist"
        if {$exist} {
            append rc " [list $name] \$[list TMP$name]"
        }  else  {
            append rc " [list $name $default]"
        }
    }
    append rc "\]\n"
    return $rc
}

proc kdata::tcl::parser_end {var} {
    upvar #0 $var v
    set rc ""
    append rc "    \}  else  \{" \n
    append rc "        return -code error -errorcode \[list KDATA UNKNOWNVERSION \$version\] -errorinfo \"Unknown package $v(_name) version \$version\" \"Unknown package $v(_name) version \$version\"" \n
    append rc "    \}" \n
    append rc "\}" \n
    append rc \n
    return $rc
}



# builder
proc kdata::tcl::builder_begin {var name version} {
    upvar #0 $var v
    set rc ""

    set v(_builderIdx) 0
    set v(_builderParams) "S"
    set v(_builderVars) "$version"
    set v(_builderCode) ""
    set v(_builderArray) [list]
    set procName $v(-namespace)::$v(-builder-prefix)[kdata::buildTitleName $name]
    
    if {$v(-create-comments)} {
        append rc "#----------------------------------------------------------------------" \n
        append rc "#" \n
        append rc "# $procName --" \n
        append rc "#" \n
        append rc "#\tBuild a \"$name\" binary structure entered as a dictionary." \n
        append rc "#" \n
        append rc "# Parameters:" \n
        append rc "#" \n
        append rc "#\tdata -- data to be parsed, as dictionary." \n
        append rc "#" \n
        append rc "# Results:" \n
        append rc "#" \n
        append rc "#\tData as binary structure." \n
        append rc "#" \n
        append rc "# Side effects:" \n
        append rc "#" \n
        append rc "#\tNone." \n
        append rc "#" \n
        append rc "#----------------------------------------------------------------------" \n
        append rc \n
    }
    append rc "proc [list $procName] \{data\} \{" \n
    return $rc
}

proc kdata::tcl::builder_element {var type name default parameters} {
    upvar #0 $var v
    set rc ""

    array set scantype {int64 W int32 I int16 S char S byte c}

    set i $v(_builderIdx)
    
    lappend v(_builderArray) $name $default
    
    if {$v(-verbose)} {
        append v(_builderCode) \n "    # converting '$name' element ($type)" \n
    }
    set val "\[dict get \$adata $name\]"

    set var tmp$i
    switch -- $type {
        int64 - int32 - int16 - byte {
            append v(_builderParams) $scantype($type)
            append v(_builderVars) " $val"
        }
        char {
            append v(_builderParams) S
            append v(_builderVars) " \[scan $val %c\]"
        }
        string {
            append v(_builderCode) "    set $var \[encoding convertto utf-8 $val\]" \n
            append v(_builderParams) "Sa*"
            append v(_builderVars) " \[string length \$$var\] \$$var"
        }
        bytearray {
            append v(_builderParams) "Ia*"
            append v(_builderVars) " \[string length $val\] $val"
        }
        element {
            set elname [kdata::buildTitleName [kdata::getNameById [lindex $parameters 0]]]
            append v(_builderCode) "    set $var \[$v(-builder-prefix)${elname} $val\]" \n
            append v(_builderParams) "Ia*"
            append v(_builderVars) " \[string length \$$var\] \$$var"
        }
        array - list {
            set elname [kdata::buildTitleName [kdata::getNameById [lindex $parameters 0]]]
            append v(_builderCode) "    set $var \"\"" \n
            append v(_builderCode) "    set l$var \[llength $val\]" \n
            append v(_builderCode) "    for \{set i 0\} \{\$i < \$l$var\} \{incr i\} \{" \n
            append v(_builderCode) "        set tmp \[$v(-builder-prefix)${elname} \[lindex $val \$i\]\]" \n
            append v(_builderCode) "        append $var \[binary format Ia* \[string length \$tmp\] \$tmp\]" \n
            append v(_builderCode) "    \}" \n
            append v(_builderParams) "Ia*"
            append v(_builderVars) " \$l$var \$$var"
        }
        primitivelist {
            append v(_builderCode) "    set $var \"\"" \n
            append v(_builderCode) "    set l$var \[llength $val\]" \n
            append v(_builderParams) "I"
            append v(_builderVars) " \$l$var"
            switch -- [lindex $parameters 0] {
                int64 - int32 - int16 - byte {
                    set st $scantype([lindex $parameters 0])
                    append v(_builderParams) "${st}*"
                    append v(_builderVars) " $val"
                }
                default {
                    set ei "Unknown primitive list datatype \"[lindex $parameters 0]\""
                    return -code error -errorcode [list KDATAPARSER UNKNOWNDATATYPE] -errorinfo $ei $ei
                }
            }
            append v(_builderVars) " \$l$var \$$var"
        }
        default {
            set ei "Unknown datatype \"$type\""
            return -code error -errorcode [list KDATAPARSER UNKNOWNDATATYPE] -errorinfo $ei $ei
        }
    }
    incr v(_builderIdx)
    return $rc
}

proc kdata::tcl::builder_end {var} {
    upvar #0 $var v
    set rc ""

    if {$v(-verbose)} {
        append rc "    # store the data as dictionary" \n
    }
    append rc "    set adata \[dict merge [list $v(_builderArray)] \$data\]" \n

    append rc $v(_builderCode)

    if {$v(-verbose)} {
        append rc \n "    # return the data" \n
    }
    append rc "    return \[binary format [list $v(_builderParams)] $v(_builderVars)\]" \n
    append rc "\}" \n
    append rc \n
    return $rc
}

# datatypes
proc kdata::tcl::datatype_begin {var name} {
    upvar #0 $var v
    set rc ""
    return $rc
}

proc kdata::tcl::datatype_element {var type name default parameters} {
    upvar #0 $var v
    set rc ""
    return $rc
}

proc kdata::tcl::datatype_end {var} {
    upvar #0 $var v
    set rc ""
    return $rc
}

# structcalls
proc kdata::tcl::structcall_begin {var name} {
    upvar #0 $var v
    set rc ""
    return $rc
}

proc kdata::tcl::structcall_element {var type name default parameters} {
    upvar #0 $var v
    set rc ""
    return $rc
}

proc kdata::tcl::structcall_end {var} {
    upvar #0 $var v
    set rc ""
    return $rc
}

# multiplexer
proc kdata::tcl::multiplexer_code_begin {var} {
    upvar #0 $var v
    set rc ""
    set v(_mxPcode) ""
    set v(_mxBcode) ""
    return $rc
}
proc kdata::tcl::multiplexer_begin {var name} {
    upvar #0 $var v
    set rc ""
    
    set id [kdata::getIdByName $name]
    set un [kdata::buildUpperName $name]
    set tn [kdata::buildTitleName $name]
    
    set v(_mxId) $id
    set v(_mxUn) $un
    set v(_mxTn) $tn
    set v(_mxDefault) ""
    set v(_mxArray) [list]
    set v(_mxIdx) 0

    # parser
    append v(_mxPcode) "$id \{" \n
    if {$v(-create-comments)} {
        append v(_mxPcode) "    # parse as $name package" \n
    }
    append v(_mxPcode) "    if \{\[binary scan \$data Ia* pkgSize data\] < 2\} \{" \n
    append v(_mxPcode) "        return -code error -errorcode \[list KDATA EOF\] -errorinfo \"End of data while parsing package $name\" \"End of data while parsing package $name\"" \n
    append v(_mxPcode) "    \}" \n

    append v(_mxPcode) "    if \{\[binary scan \$data a\$\{pkgSize\}a* pkgdata data\] < 2\} \{" \n
    append v(_mxPcode) "        return -code error -errorcode \[list KDATA EOF\] -errorinfo \"End of data while parsing package $name\" \"End of data while parsing package $name\"" \n
    append v(_mxPcode) "    \}" \n

    if {$v(-debug)} {
        append v(_mxPcode) "    puts \"Parsing $name package - \[string length \$pkgdata\] byte(s)\"" \n
    }
    append v(_mxPcode) "    lappend rc \"$name\" \[$v(-parser-prefix)$tn \$pkgdata\]" \n
    append v(_mxPcode) "\}" \n
    
    # builder
    append v(_mxBcode) "$name - $tn - $un \{" \n
    append v(_mxBcode) "    set tmp \[$v(-builder-prefix)$tn \$data\]" \n
    append v(_mxBcode) "    set rc \[binary format a*IIa* \$rc $id \[string length \$tmp\] \$tmp\]" \n
    append v(_mxBcode) "\}" \n
    return $rc
}

proc kdata::tcl::multiplexer_element {var type name default parameters} {
    upvar #0 $var v
    set rc ""
    append v(_mxDefault) " $name"

    if {$type == "element"} {
        set etn [kdata::buildTitleName [kdata::getNameById [lindex $parameters 0]]]
        append v(_mxDefault) " \[$v(-create-prefix)$etn\]"
    }  else  {
        append v(_mxDefault) " " [list $default]
    }
    return $rc
}

proc kdata::tcl::multiplexer_end {var} {
    upvar #0 $var v
    set rc ""
    set tn $v(_mxTn)
    
    # create default values
    set procName $v(-namespace)::$v(-create-prefix)$tn
    
    if {$v(-create-comments)} {
        append rc "#----------------------------------------------------------------------" \n
        append rc "#" \n
        append rc "# $procName --" \n
        append rc "#" \n
        append rc "#\tReturns a $tn object with all default values." \n
        append rc "#" \n
        append rc "# Parameters:" \n
        append rc "#" \n
        append rc "#\tNone." \n
        append rc "#" \n
        append rc "# Results:" \n
        append rc "#" \n
        append rc "#\tPackage, stored as dictionary." \n
        append rc "#" \n
        append rc "# Side effects:" \n
        append rc "#" \n
        append rc "#\tNone." \n
        append rc "#" \n
        append rc "#----------------------------------------------------------------------" \n
        append rc \n
    }
    append rc "proc $procName \{args\} \{" \n
    append rc "    return \[dict merge \[dict create$v(_mxDefault)\] \$args\]" \n
    append rc "\}" \n
    append rc \n
    
    # field index
    set procName $v(-namespace)::$v(-idx-prefix)$tn
    set varName $v(-idx-prefix)$tn
    
    return $rc
}

proc kdata::tcl::multiplexer_code_end {var} {
    upvar #0 $var v
    set rc ""
    if {$v(-create-comments)} {
        append rc "#----------------------------------------------------------------------" \n
        append rc "#" \n
        append rc "# $v(-namespace)::parsePackages --" \n
        append rc "#" \n
        append rc "#\tReturns a type-value list of all packages parsed." \n
        append rc "#" \n
        append rc "# Parameters:" \n
        append rc "#" \n
        append rc "#\tdata -- binary data to be parsed" \n
        append rc "#" \n
        append rc "# Results:" \n
        append rc "#" \n
        append rc "#\tList of all packages, grouped as package type and data pairs." \n
        append rc "#" \n
        append rc "# Side effects:" \n
        append rc "#" \n
        append rc "#\tNone." \n
        append rc "#" \n
        append rc "#----------------------------------------------------------------------" \n
        append rc \n
    }
    append rc "proc $v(-namespace)::parsePackages \{data\} \{" \n
    append rc "    set rc \[list\]" \n
    append rc "    if \{!\[binary scan \$data Ia* count data\]\} \{" \n
    append rc "        return \[list\]" \n
    append rc "    \}" \n
    append rc "    " \n
    append rc "    for \{set i 0\} \{\$i < \$count\} \{incr i\} \{" \n
    append rc "        if \{!\[binary scan \$data Ia* pkgId data\]\} \{" \n
    append rc "            return \[list\]" \n
    append rc "        \}" \n
    append rc "        switch -- \$pkgId \{" \n
    set space "            "
    append rc $space [join [split $v(_mxPcode) \n] "\n${space}"] \n
    append rc "            default \{" \n
    append rc "                return -code error -errorinfo \"Unknown package ID \\\"\$pkgId\\\"\"  -errorcode \[list KDATA UNKNOWNPACKAGE\] \"Unknown package ID \\\"\$pkgId\\\"\"" \n
    append rc "            \}" \n
    append rc "        \}" \n
    append rc "    \}" \n
    append rc "    return \$rc" \n
    append rc "\}" \n
    append rc \n

    if {$v(-create-comments)} {
        append rc "#----------------------------------------------------------------------" \n
        append rc "#" \n
        append rc "# $v(-namespace)::buildPackages --" \n
        append rc "#" \n
        append rc "#\tBuilds binary data from a list of packages." \n
        append rc "#" \n
        append rc "# Parameters:" \n
        append rc "#" \n
        append rc "#\tdata -- a type-data pair list of all packages" \n
        append rc "#" \n
        append rc "# Results:" \n
        append rc "#" \n
        append rc "#\tBinary data storing all the packages." \n
        append rc "#" \n
        append rc "# Side effects:" \n
        append rc "#" \n
        append rc "#\tNone." \n
        append rc "#" \n
        append rc "#----------------------------------------------------------------------" \n
        append rc \n
    }
    append rc "proc $v(-namespace)::buildPackages \{data\} \{" \n
    append rc "    set rc \[binary format I \[expr \{\[llength \$data\] / 2\}\]\]" \n

    append rc "    foreach \{type data\} \$data \{" \n
    append rc "        switch -exact -- \$type \{" \n
    set space "            "
    append rc $space [join [split $v(_mxBcode) \n] "\n${space}"] \n
    append rc "            default \{" \n
    append rc "                return -code error -errorinfo \"Unknown package \\\"\$type\\\"\"  -errorcode \[list KDATA UNKNOWNPACKAGE\] \"Unknown package \\\"\$type\\\"\"" \n
    append rc "            \}" \n
    append rc "        \}" \n
    append rc "    \}" \n
    append rc "    return \$rc" \n
    append rc "\}" \n
    append rc \n
    return $rc
}

proc kdata::tcl::enum_begin {var name} {
    upvar #0 $var v
    set rc ""
    if {$v(-create-comments)} {
        append rc "#" \n
        append rc "# Enum $name:" \n
        append rc "#" \n
    }
    return $rc
}

proc kdata::tcl::enum_value {var enumName enumVKey enumValue} {
    upvar #0 $var v
    set rc ""
    append rc [list set $v(-namespace)::[kdata::buildTitleName $enumName]([kdata::buildUpperName $enumVKey]) $enumValue] \n
    return $rc
}

proc kdata::tcl::enum_end {var name} {
    upvar #0 $var v
    set rc ""
    append rc "" \n
    return $rc
}

package provide kdata::language::tcl 1.0
