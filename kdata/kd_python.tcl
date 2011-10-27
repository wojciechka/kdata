#
# (c) 2011 Wojciech Kocjan
# Licensed under BSD-style license
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#

namespace eval kdata::python {}

set kdata::python::default [list \
    ]

proc kdata::python::escapeString {s} {
    # TODO: real mapping needed here
    set s [string map [list \\ \\\\ \" \\\"] $s]
    return "\"$s\""
}

proc kdata::python::code_begin {var} {
    upvar #0 $var v
    set rc ""
    append rc "from struct import pack, unpack" \n
    append rc "#" \n
    append rc "# CODE GENERATED USING kdata::language::python 1.0" \n
    append rc "#" \n
    append rc "# DO NOT EDIT BY HAND" \n
    append rc "#" \n
    append rc "" \n

    append rc "class KdataError(Exception):" \n
    if {$v(-create-comments)} {
        append rc "    \"\"\"Generic Kdata error, inherited by all specific errors" \n
        append rc "    \"\"\"" \n
    }
    append rc "    pass" \n
    append rc "" \n

    append rc "class KdataUnknownDatatypeError(KdataError):" \n
    if {$v(-create-comments)} {
        append rc "    \"\"\"Error parsing unknown datatype when demultiplexing" \n
        append rc "    \"\"\"" \n
    }
    append rc "    pass" \n
    append rc "" \n

    append rc "class KdataUnknownVersionError(KdataError):" \n
    if {$v(-create-comments)} {
        append rc "    \"\"\"Unknown package version" \n
        append rc "    \"\"\"" \n
    }
    append rc "    pass" \n
    append rc "" \n

    return $rc
}

proc kdata::python::code_end {var} {
    upvar #0 $var v
    set rc ""
    return $rc
}


# parser
proc kdata::python::parser_begin {var name} {
    upvar #0 $var v
    set v(_versionfirst) true
    set v(_name) $name
    set rc ""
    
    set procName $v(-parser-prefix)[kdata::buildTitleName $name]
    
    if {$v(-create-comments)} {
        # TODO: create comments
    }
    append rc "" \n
    append rc "def ${procName}(data):" \n
    if {$v(-create-comments)} {
        append rc "    \"\"\"Unpack binary representation of [kdata::buildTitleName ${name}] class." \n
        append rc "    " \n
        append rc "    data: Binary data to unpack" \n
        append rc "    " \n
        append rc "    Returns new instance of [kdata::buildTitleName ${name}] class or raises error for invalid data" \n
        append rc "    \"\"\"" \n
    }
    if {$v(-verbose)} {
        append rc \n "    # getting the package version number." \n
    }
    append rc "    version = unpack(\">H\", data\[0:2\])\[0\]" \n
    append rc "    data = data\[2:\]" \n
    append rc "    rc = [kdata::buildTitleName ${name}]()" \n
    return $rc
}

proc kdata::python::parser_version_begin {var version} {
    upvar #0 $var v
    set rc ""
    if {$v(_versionfirst)} {
        set v(_versionfirst) false
        append rc "    if version == $version:" \n
    }  else  {
        append rc "    elif version == $version:" \n
    }
    return $rc
}

proc kdata::python::parser_element {var type name default parameters} {
    upvar #0 $var v
    set rc ""
    if {$v(-verbose)} {
        append rc \n "        # trying to fetch '$name' element ($type)" \n
    }
    array set scantype {int64 q int32 i int16 h byte b}
    array set scanlen  {int64 8 int32 4 int16 2 byte 1}
    switch -- $type {
        int64 - int32 - int16 - byte {
            set st $scantype($type)
            set sl $scanlen($type)
            append rc "        rc.${name} = unpack(\">${st}\", data\[0:${sl}\])\[0\]" \n
            append rc "        data = data\[${sl}:\]" \n
        }
        char {
            append rc "        rc.${name} = unichr(unpack(\">h\", data\[0:2\])\[0\])" \n
            append rc "        data = data\[2:\]" \n
        }
        string {
            append rc "        rclen = unpack(\">h\", data\[0:2\])\[0\]" \n
            append rc "        rc.${name} = data\[2:2 + rclen].decode(\"UTF-8\")" \n
            append rc "        data = data\[2 + rclen:\]" \n
        }
        bytearray {
            append rc "        rclen = unpack(\">i\", data\[0:4\])\[0\]" \n
            append rc "        rc.${name} = data\[4:4 + rclen]" \n
            append rc "        data = data\[4 + rclen:\]" \n
        }
        element {
            set elname [kdata::buildTitleName [kdata::getNameById [lindex $parameters 0]]]
            append rc "        rclen = unpack(\">i\", data\[0:4\])\[0\]" \n
            append rc "        rc.${name} = $v(-parser-prefix)${elname}(data\[4:4 + rclen])" \n
            append rc "        data = data\[4 + rclen:\]" \n
        }
        array - list {
            set elname [kdata::buildTitleName [kdata::getNameById [lindex $parameters 0]]]
            append rc "        rc.${name} = \[\]" \n
            append rc "        rccount = unpack(\">i\", data\[0:4\])\[0\]" \n
            append rc "        data = data\[4:\]" \n
            append rc "        for rci in range(rccount):" \n
            append rc "            rclen = unpack(\">i\", data\[0:4\])\[0\]" \n
            append rc "            rc.${name}.append($v(-parser-prefix)${elname}(data\[4:4 + rclen\]))" \n
            append rc "            data = data\[4 + rclen:\]" \n
        }
        primitivelist {
            append rc "        rccount = unpack(\">i\", data\[0:4\])\[0\]" \n
            append rc "        if rccount == 0:" \n
            append rc "            rc.${name} = \[\]" \n
            append rc "            data = data\[4:\]" \n
            append rc "        else:" \n
            switch -- [lindex $parameters 0] {
                int64 - int32 - int16 - byte {
                    set st $scantype([lindex $parameters 0])
                    set sl $scanlen([lindex $parameters 0])
                    append rc "            rc.${name} = list(unpack(\">\" + \"i\" * rccount, data\[4:4+(${sl}*rccount)\]))" \n
                    append rc "            data = data\[4+(${sl}*rccount):\]" \n
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

proc kdata::python::parser_version_end {var all existing nonexisting} {
    upvar #0 $var v
    set rc ""
    return $rc
}

proc kdata::python::parser_end {var} {
    upvar #0 $var v
    set rc ""
    append rc "    else:" \n
    append rc "        raise KdataUnknownVersionError(\"Unknown package $v(_name) version\")" \n
    append rc "    return rc" \n
    append rc \n
    return $rc
}



# builder
proc kdata::python::builder_begin {var name version} {
    upvar #0 $var v
    set v(_versionfirst) true
    set v(_name) $name
    set rc ""
    
    set procName "$v(-builder-prefix)[kdata::buildTitleName $name]"
    
    append rc "" \n
    append rc "def ${procName}(data):" \n
    if {$v(-create-comments)} {
        append rc "    \"\"\"Pack instance of [kdata::buildTitleName $name] to binary." \n
        append rc "    " \n
        append rc "    data: Instance of [kdata::buildTitleName $name] to pack" \n
        append rc "    " \n
        append rc "    Returns binary representation of class, suitable for calling $v(-parser-prefix)[kdata::buildTitleName $name]" \n
        append rc "    \"\"\"" \n
    }
    append rc "    rc = \"\"" \n
    append rc "    rc += pack(\">H\", $version)" \n
    return $rc
}

proc kdata::python::builder_element {var type name default parameters} {
    upvar #0 $var v
    set rc ""
    array set scantype {int64 q int32 i int16 h byte b}
    switch -- $type {
        int64 - int32 - int16 - byte {
            set st $scantype($type)
            append rc "    rc += pack(\">${st}\", data.${name})" \n
        }
        byte {
            append rc "    rc += pack(\">b\", data.${name})" \n
        }
        string {
            append rc "    rcstr = (data.${name}).encode(\"UTF-8\")" \n
            append rc "    rc += pack(\">h\", len(rcstr)) + rcstr" \n
        }
        bytearray {
            append rc "    rc += pack(\">i\", len(data.${name})) + data.${name}" \n
        }
        element {
            set elname [kdata::buildTitleName [kdata::getNameById [lindex $parameters 0]]]
            append rc "    rcdata = $v(-builder-prefix)${elname}(data.${name})" \n
            append rc "    rc += pack(\">i\", len(rcdata)) + rcdata" \n
        }
        array - list {
            set elname [kdata::buildTitleName [kdata::getNameById [lindex $parameters 0]]]
            append rc "    rcdata = pack(\">i\", len(data.${name}))" \n
            append rc "    for rci in data.${name}:" \n
            append rc "        rcidata = $v(-builder-prefix)${elname}(rci)" \n
            append rc "        rcdata += pack(\">i\", len(rcidata)) + rcidata" \n
            append rc "    rc += rcdata" \n
        }
        primitivelist {
            switch -- [lindex $parameters 0] {
                int64 - int32 - int16 - byte {
                    set st $scantype([lindex $parameters 0])
                    append rc "    rc += pack(\">i\" + \"${st}\" * len(data.${name}), len(data.${name}), *(data.${name}))" \n
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

proc kdata::python::builder_end {var} {
    upvar #0 $var v
    set rc ""
    append rc "    return rc" \n
    append rc "" \n
    return $rc
}

# datatypes
proc kdata::python::datatype_begin {var name} {
    upvar #0 $var v
    set rc ""
    append rc "class [kdata::buildTitleName ${name}]:" \n
    append rc "    def __init__(self, **kwargs):" \n
    return $rc
}

proc kdata::python::datatype_element {var type name default parameters} {
    upvar #0 $var v
    set rc ""
    append rc "        if \"${name}\" in kwargs:" \n
    append rc "            self.${name} = kwargs\[\"${name}\"\]" \n
    append rc "        else:" \n
    switch -- $type {
        int64 - int32 - int16 - byte {
            append rc "            self.${name} = ${default}" \n
        }
        char - string - bytearray {
            append rc "            self.${name} = [escapeString ${default}]" \n
        }
        element {
            set elname [kdata::buildTitleName [kdata::getNameById [lindex $parameters 0]]]
            append rc "            self.${name} = ${elname}()" \n
        }
        array - list {
            append rc "            self.${name} = \[\]" \n
        }
        primitivelist {
            append rc "            self.${name} = \[\]" \n
        }
        default {
            set ei "Unknown datatype \"$type\""
            return -code error -errorcode [list KDATAPARSER UNKNOWNDATATYPE] -errorinfo $ei $ei
        }

    }
    return $rc
}

proc kdata::python::datatype_end {var} {
    upvar #0 $var v
    set rc ""
    append rc "        pass" \n
    return $rc
}

# structcalls
proc kdata::python::structcall_begin {var name} {
    upvar #0 $var v
    set rc ""
    return $rc
}

proc kdata::python::structcall_element {var type name default parameters} {
    upvar #0 $var v
    set rc ""
    return $rc
}

proc kdata::python::structcall_end {var} {
    upvar #0 $var v
    set rc ""
    return $rc
}

# multiplexer
proc kdata::python::multiplexer_code_begin {var} {
    upvar #0 $var v
    set rc ""
    set v(_mxPcode) ""
    set v(_mxBcode) ""
    return $rc
}
proc kdata::python::multiplexer_begin {var name} {
    upvar #0 $var v
    set rc ""

    set id [kdata::getIdByName $name]
    set un [kdata::buildUpperName $name]
    set tn [kdata::buildTitleName $name]

    if {$v(_mxBcode) == ""} {
        append v(_mxBcode) "if isinstance(item, [kdata::buildTitleName ${name}]):" \n
    }  else  {
        append v(_mxBcode) "elif isinstance(item, [kdata::buildTitleName ${name}]):" \n
    }
    append v(_mxBcode) "    id = $id" \n
    append v(_mxBcode) "    d = $v(-builder-prefix)[kdata::buildTitleName $name](item)" \n

    if {$v(_mxPcode) == ""} {
        append v(_mxPcode) "if pkgId == $id:" \n
    }  else  {
        append v(_mxPcode) "elif pkgId == $id:" \n
    }
    append v(_mxPcode) "    i = $v(-parser-prefix)[kdata::buildTitleName $name](item)" \n

    return $rc
}

proc kdata::python::multiplexer_element {var type name default parameters} {
    upvar #0 $var v
    set rc ""
    return $rc
}

proc kdata::python::multiplexer_end {var} {
    upvar #0 $var v
    set rc ""
    return $rc
}

proc kdata::python::multiplexer_code_end {var} {
    upvar #0 $var v
    set rc ""
    append rc "" \n
    append rc "def $v(-builder-prefix)Packages(data):" \n
    if {$v(-create-comments)} {
        append rc "    \"\"\"Pack one or more instances of any known objects as binary data." \n
        append rc "    " \n
        append rc "    data: List of instances to pack" \n
        append rc "    " \n
        append rc "    Returns binary representation of classes, suitable for calling $v(-parser-prefix)Packages" \n
        append rc "    \"\"\"" \n
    }
    append rc "    rc = pack(\">i\", len(data))" \n
    append rc "    for item in data:" \n
    append rc "        id = None" \n
    append rc "        " [join [split $v(_mxBcode) \n] "\n        "] \n
    append rc "        if id == None:" \n
    append rc "            raise KdataUnknownDatatypeError(type(item))" \n
    append rc "        rc += (pack(\">ii\", id, len(d)) + d)" \n
    # safety precaution
    append rc "    return rc" \n
    append rc "" \n

    append rc "def $v(-parser-prefix)Packages(data):" \n
    if {$v(-create-comments)} {
        append rc "    \"\"\"Unpack one or more instances of any known objects as binary data." \n
        append rc "    " \n
        append rc "    data: Binary data to unpack as one or more instances" \n
        append rc "    " \n
        append rc "    Returns one or more instances or throws error in case of invalid data" \n
        append rc "    \"\"\"" \n
    }
    append rc "    rc = \[\]" \n
    append rc "    count = unpack(\">i\", data\[0:4\])\[0\]" \n
    append rc "    data = data\[4:\]" \n
    append rc "    for i in range(count):" \n
    append rc "        (pkgId, pkgSize) = unpack(\">ii\", data\[0:8\])" \n
    append rc "        item = data\[8:8 + pkgSize\]" \n
    append rc "        data = data\[8 + pkgSize:\]" \n
    append rc "        i = None" \n
    append rc "        " [join [split $v(_mxPcode) \n] "\n        "] \n
    append rc "        if i == None:" \n
    append rc "            raise KdataUnknownDatatypeError(pkgId)" \n
    append rc "        rc.append(i)" \n
    append rc "    return rc" \n
    return $rc
}

proc kdata::python::enum_begin {var name} {
    upvar #0 $var v
    set rc ""
    append rc "" \n
    append rc "class [kdata::buildTitleName $name]:" \n
    if {$v(-create-comments)} {
        append rc "    \"\"\"Enumeration $name" \n
        append rc "    \"\"\"" \n
    }
    return $rc
}

proc kdata::python::enum_value {var enumName enumVKey enumValue} {
    upvar #0 $var v
    set rc ""
    append rc "    [kdata::buildUpperName $enumVKey] = $enumValue" \n
    return $rc
}

proc kdata::python::enum_end {var name} {
    upvar #0 $var v
    set rc ""
    # just to be sure in case no enums are currently defined
    append rc "    pass" \n
    return $rc
}

package provide kdata::language::python 1.0
