#
# (c) 2004-2011 Wojciech Kocjan
# Licensed under BSD-style license
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#

#package provide kdata::language::SKEL 1.0

namespace eval kdata::SKEL {}

set kdata::SKEL::default [list \
    -class 				"" \
    ]

proc kdata::SKEL::code_begin {var} {
    upvar #0 $var v
    set rc ""
    return $rc
}

proc kdata::SKEL::code_end {var} {
    upvar #0 $var v
    set rc ""
    return $rc
}


# parser
proc kdata::SKEL::parser_begin {var name} {
    upvar #0 $var v
    return $rc
}

proc kdata::SKEL::parser_version_begin {var version} {
    upvar #0 $var v
    set rc ""
    return $rc
}

proc kdata::SKEL::parser_element {var type name default parameters} {
    upvar #0 $var v
    set rc ""
    return $rc
}

proc kdata::SKEL::parser_version_end {var all existing nonexisting} {
    upvar #0 $var v
    set rc ""
    return $rc
}

proc kdata::SKEL::parser_end {var} {
    upvar #0 $var v
    set rc ""
    return $rc
}



# builder
proc kdata::SKEL::builder_begin {var name version} {
    upvar #0 $var v
    set rc ""
    return $rc
}

proc kdata::SKEL::builder_element {var type name default parameters} {
    upvar #0 $var v
    set rc ""
    return $rc
}

proc kdata::SKEL::builder_end {var} {
    upvar #0 $var v
    set rc ""
    return $rc
}

# datatypes
proc kdata::SKEL::datatype_begin {var name} {
    upvar #0 $var v
    set rc ""
    return $rc
}

proc kdata::SKEL::datatype_element {var name} {
    upvar #0 $var v
    set rc ""
    return $rc
}

proc kdata::SKEL::datatype_end {var} {
    upvar #0 $var v
    set rc ""
    return $rc
}

# structcalls
proc kdata::SKEL::structcall_begin {var name} {
    upvar #0 $var v
    set rc ""
    return $rc
}

proc kdata::SKEL::structcall_element {var name} {
    upvar #0 $var v
    set rc ""
    return $rc
}

proc kdata::SKEL::structcall_end {var} {
    upvar #0 $var v
    set rc ""
    return $rc
}

# datatypes
proc kdata::SKEL::multiplexer_begin {var name} {
    upvar #0 $var v
    set rc ""
    return $rc
}

proc kdata::SKEL::multiplexer_element {var name} {
    upvar #0 $var v
    set rc ""
    return $rc
}

proc kdata::SKEL::multiplexer_end {var} {
    upvar #0 $var v
    set rc ""
    return $rc
}

proc kdata::SKEL::enum_begin {name} {
}

proc kdata::SKEL::enum_value {enumName enumVKey enumValue} {
}

proc kdata::SKEL::enum_end {name} {
}

