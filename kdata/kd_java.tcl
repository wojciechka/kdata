#
# (c) 2004-2011 Wojciech Kocjan
# Licensed under BSD-style license
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#

namespace eval kdata::java {}

set kdata::java::default [list \
    -class                              "" \
    -create-creator                     false \
    -creator-prefix                     "create" \
    -datatype-build                     true \
    -receiver-prefix                    receive \
    -mxtype-prefix                      "MESSAGE" \
    -create-mx-receiver                 true \
    -create-mx-parser                   true \
    -create-mx-builder                  true \
    -create-javadoc                     true \
    -suppress-warnings                  true \
    ]

proc kdata::java::primitive2java {type} {
    if {$type == "int32"} {
        return "Integer"
    }  else  {
        set ei "Unknown primitive list datatype \"[lindex $parameters 0]\""
        return -code error -errorcode [list KDATAPARSER UNKNOWNDATATYPE] -errorinfo $ei $ei
    }
}

proc kdata::java::version {} {
    return "1.0"
}

proc kdata::java::code_begin {var} {
    upvar #0 $var v
    
    set csplit [split $v(-class) .]
    if {[llength $csplit]==0} {
        set ei "Invalid Java class name"
        return -code error -errorinfo $ei $ei
    }
    
    set rc ""
    
    set v(_pkg) [join [lrange $csplit 0 end-1] .]
    set v(_class) [lindex $csplit end]

    if {$v(_pkg)!=""} {
        append rc "package $v(_pkg);" \n\n
    }
    
    append rc "import java.io.*;" \n
    append rc "import java.util.*;" \n
    
    if {$v(-create-javadoc)} {
        append rc "/**" \n
        append rc " * Class for handling binary data." \n
        append rc " * <br><br>" \n
        append rc " * This class allows creating all the structures," \n
        append rc " * converting them to binary data <i>(using $v(-builder-prefix)* methods)</i>," \n
        append rc " * converting from binary data to objects <i>(using $v(-parser-prefix)* methods)</i>," \n
        append rc " * converting multiple objects to binary data <i>(using buildPackages method)</i>," \n
        append rc " * converting binary data back to multiple objects <i>(using receivePackages* and parsePackages* method)</i>," \n
        append rc " * and is mostly backwards compatible after structure changes." \n
        append rc " * <br><br>" \n
        append rc " * <i>Body of the class was generated automatically by kdata::java package [version]," \n
        append rc " * at [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}].</i>" \n
        append rc " * " \n
        append rc " * @author KdataGenerator" \n
        append rc " */" \n
    }
    
    if {$v(-suppress-warnings)} {
        append rc "@SuppressWarnings(\"unused\")\n"
    }
    append rc "public class $v(_class) \{" \n
    if {$v(-create-javadoc)} {
        append rc "    /**" \n
        append rc "     * Construct a $v(_class) object." \n
        append rc "     */" \n
    }
    append rc "    public $v(_class)() \{" \n
    append rc "    \}" \n
    return $rc
}

proc kdata::java::code_end {var} {
    upvar #0 $var v
    set rc ""
    append rc "\}" \n
    return $rc
}


# parser
proc kdata::java::parser_begin {var name} {
    upvar #0 $var v
    
    set v(_dtclass) [kdata::buildTitleName $name]
    set v(_firstversion) true

    set rc ""
    if {$v(-create-javadoc)} {
        append rc "    /**" \n
        append rc "     * Function that parses data and tries to create an appropriate object of it." \n
        append rc "     *" \n
        append rc "     * @param data an array of bytes to be parsed." \n
        append rc "     * @return a <i>$v(_dtclass)</i> class object or null if parsing has failed." \n
        append rc "     * @throws EOFException" \n
        append rc "     * @throws IOException" \n
        append rc "     */" \n
    }
    append rc "    public static $v(_dtclass) $v(-parser-prefix)$v(_dtclass)(byte\[\] data) throws EOFException, IOException \{" \n
    append rc "        short version;" \n
    append rc "        int j, l;" \n
    append rc "        byte\[\] ba;" \n
    append rc "        $v(_dtclass) retVal = new $v(_dtclass)();" \n
    append rc "        ByteArrayInputStream bytesInputStream = new ByteArrayInputStream(data);" \n
    append rc "        DataInputStream dataInputStream = new DataInputStream(bytesInputStream);" \n
    append rc "        try \{" \n
    append rc "            version = dataInputStream.readShort();" \n
    return $rc
}

proc kdata::java::parser_version_begin {var version} {
    upvar #0 $var v
    set rc ""
    if {$v(_firstversion)} {
        set v(_firstversion) false
        append rc "            if (version == $version) \{" \n
    }  else  {
        append rc "            else if (version == $version) \{" \n
    }
    if {$v(-create-comments)} {
        append rc "                /* Parsing version $version. */" \n
    }
    return $rc
}

proc kdata::java::parser_element {var type name default parameters} {
    upvar #0 $var v
    set rc ""
    if {$v(-create-comments)} {
        append rc \n "                /*  Reading element '$name' (type $type). */" \n
    }
    if {$v(-debug)} {
        append rc "                System.out.println(\"Reading '$name' (type $type) element\");" \n
    }
    switch -- $type {
        int64 {
            append rc "                retVal.$name = dataInputStream.readLong();" \n
        }
        int32 {
            append rc "                retVal.$name = dataInputStream.readInt();" \n
        }
        int16 {
            append rc "                retVal.$name = dataInputStream.readShort();" \n
        }
        byte {
            append rc "                retVal.$name = dataInputStream.readByte();" \n
        }
        char {
            append rc "                retVal.$name = dataInputStream.readChar();" \n
        }
        string {
            append rc "                retVal.$name = dataInputStream.readUTF();" \n
        }
        bytearray {
            append rc "                l = dataInputStream.readInt();" \n
            append rc "                ba = new byte\[l\];" \n
            append rc "                if (l > 0)" \n
            append rc "                    dataInputStream.readFully(ba);" \n
            append rc "                retVal.$name = ba;" \n
        }
        array {
            set childclass [kdata::buildTitleName [kdata::getNameById [lindex $parameters 0]]]
            append rc "                l = dataInputStream.readInt();" \n
            append rc "                retVal.$name = new ${childclass}\[l\];" \n
            append rc "                for (int i = 0; i < l; i++) \{" \n
            if {$v(-debug)} {
                append rc "                    System.out.println(\"$name: \"+i+\" / \"+l);" \n
            }
            append rc "                    j = dataInputStream.readInt();" \n
            append rc "                    ba = new byte\[j\];" \n
            append rc "                    if (j > 0)" \n
            append rc "                        dataInputStream.readFully(ba);" \n
            append rc "                    retVal.$name\[i\] = $v(-parser-prefix)${childclass}\(ba\);" \n
            append rc "                \}" \n
        }
        list {
            set childclass [kdata::buildTitleName [kdata::getNameById [lindex $parameters 0]]]
            append rc "                l = dataInputStream.readInt();" \n
            append rc "                retVal.$name = new ArrayList<$childclass>();" \n
            append rc "                for (int i = 0; i < l; i++) \{" \n
            if {$v(-debug)} {
                append rc "                    System.out.println(\"$name: \"+i+\" / \"+l);" \n
            }
            append rc "                    j = dataInputStream.readInt();" \n
            append rc "                    ba = new byte\[j\];" \n
            append rc "                    if (j > 0)" \n
            append rc "                        dataInputStream.readFully(ba);" \n
            append rc "                    retVal.$name.add($v(-parser-prefix)${childclass}\(ba\));" \n
            append rc "                \}" \n
        }
        primitivelist {
            set ptype [primitive2java [lindex $parameters 0]]
            append rc "                l = dataInputStream.readInt();" \n
            append rc "                retVal.$name = new ArrayList<$ptype>();" \n
            append rc "                for (int i = 0; i < l; i++) \{" \n
            switch -- [lindex $parameters 0] {
                int32 {
                    append rc "                    retVal.$name.add(new ${ptype}(dataInputStream.readInt()));" \n
                }
            }
            append rc "                \}" \n
        }
        element {
            set childclass [kdata::buildTitleName [kdata::getNameById [lindex $parameters 0]]]
            append rc "                l = dataInputStream.readInt();" \n
            append rc "                ba = new byte\[l\];" \n
            append rc "                if (l > 0)" \n
            append rc "                    dataInputStream.readFully(ba);" \n
            append rc "                retVal.$name = $v(-parser-prefix)${childclass}(ba);" \n
        }
        default {
            set ei "Unknown datatype \"$type\""
            return -code error -errorcode [list KDATAPARSER UNKNOWNDATATYPE] -errorinfo $ei $ei
        }
    }
    return $rc
}

proc kdata::java::parser_version_end {var all existing nonexisting} {
    upvar #0 $var v
    set rc ""
    append rc "            \}" \n
    return $rc
}

proc kdata::java::parser_end {var} {
    upvar #0 $var v
    set rc ""
    append rc "            else \{" \n
    append rc "            \}" \n
    append rc "        \}" \n
    append rc "        catch (EOFException exception)  \{" \n
    if {$v(-create-comments)} {
        append rc \n "            /* Try closing DataInputStream before throwing an error. */" \n
    }
    append rc "            if (dataInputStream != null) \{" \n
    append rc "                try \{" \n
    append rc "                    dataInputStream.close();" \n
    append rc "                \} catch (Exception e) \{\}" \n
    append rc "            \}" \n
    if {$v(-create-comments)} {
        append rc \n "            /* Try closing ByteArrayInputStream before thworing an error. */" \n
    }
    append rc "            if (bytesInputStream != null) \{" \n
    append rc "                try \{" \n
    append rc "                    bytesInputStream.close();" \n
    append rc "                \} catch (Exception e) \{\}" \n
    append rc "            \}" \n
    append rc "            throw exception;" \n
    append rc "        \}" \n
    append rc "        catch (IOException exception)  \{" \n
    if {$v(-create-comments)} {
        append rc \n "            /* Try closing DataInputStream before throwing an error. */" \n
    }
    append rc "            if (dataInputStream != null) \{" \n
    append rc "                try \{" \n
    append rc "                    dataInputStream.close();" \n
    append rc "                \} catch (Exception e) \{\}" \n
    append rc "            \}" \n
    if {$v(-create-comments)} {
        append rc \n "            /* Try closing ByteArrayInputStream before thworing an error. */" \n
    }
    append rc "            if (bytesInputStream != null) \{" \n
    append rc "                try \{" \n
    append rc "                    bytesInputStream.close();" \n
    append rc "                \} catch (Exception e) \{\}" \n
    append rc "            \}" \n
    append rc "            throw exception;" \n
    append rc "        \}" \n
    if {$v(-create-comments)} {
        append rc \n "        /* Try closing DataInputStream before returning. */" \n
    }
    append rc "        if (dataInputStream != null) \{" \n
    append rc "            try \{" \n
    append rc "                dataInputStream.close();" \n
    append rc "            \} catch (Exception e) \{\}" \n
    append rc "        \}" \n
    if {$v(-create-comments)} {
        append rc \n "        /* Try closing ByteArrayInputStream before returning. */" \n
    }
    append rc "        if (bytesInputStream != null) \{" \n
    append rc "            try \{" \n
    append rc "                bytesInputStream.close();" \n
    append rc "            \} catch (Exception e) \{\}" \n
    append rc "        \}" \n
    append rc "        return retVal;" \n
    append rc "    \}" \n\n
    return $rc
}



# builder
proc kdata::java::builder_begin {var name version} {
    upvar #0 $var v
    set v(_dtclass) [kdata::buildTitleName $name]
    set v(_firstversion) true

    set rc ""
    if {$v(-create-javadoc)} {
        append rc "    /**" \n
        append rc "     * Function that creates binary data out of an object." \n
        append rc "     *" \n
        append rc "     * @param data object of <i>$v(_dtclass)</i> class to create binary form from." \n
        append rc "     * @return array of bytes." \n
        append rc "     * @throws IOException" \n
        append rc "     */" \n
    }
    append rc "    public static byte\[\] $v(-builder-prefix)$v(_dtclass)($v(_dtclass) data) throws IOException \{" \n
    append rc "        int i, j, k, l;" \n
    append rc "        byte\[\] ba;" \n
    append rc "        ByteArrayOutputStream bytesOutputStream = new ByteArrayOutputStream();" \n
    append rc "        DataOutputStream dataOutputStream = new DataOutputStream(bytesOutputStream);" \n
    append rc "        byte\[\] retVal;" \n
    append rc "        try \{" \n
    append rc "            dataOutputStream.writeShort($version);" \n
    return $rc
}

proc kdata::java::builder_element {var type name default parameters} {
    upvar #0 $var v
    set rc ""
    if {$v(-create-comments)} {
        append rc \n "            /*  Writing element '$name' (type $type). */" \n
    }
    switch -- $type {
        int64 {
            append rc "            dataOutputStream.writeLong(data.$name);" \n
        }
        int32 {
            append rc "            dataOutputStream.writeInt(data.$name);" \n
        }
        int16 {
            append rc "            dataOutputStream.writeShort(data.$name);" \n
        }
        byte {
            append rc "            dataOutputStream.writeByte(data.$name);" \n
        }
        char {
            append rc "            dataOutputStream.writeChar(data.$name);" \n
        }
        string {
            append rc "            dataOutputStream.writeUTF(data.$name);" \n
        }
        bytearray {
            append rc "            dataOutputStream.writeInt(data.$name.length);" \n
            append rc "            dataOutputStream.write(data.$name, 0, data.$name.length);" \n
        }
        element {
            set childclass [kdata::buildTitleName [kdata::getNameById [lindex $parameters 0]]]
            append rc "            ba = $v(-builder-prefix)${childclass}(data.$name);" \n
            append rc "            dataOutputStream.writeInt(ba.length);" \n
            append rc "            dataOutputStream.write(ba, 0, ba.length);" \n
        }
        array {
            set childclass [kdata::buildTitleName [kdata::getNameById [lindex $parameters 0]]]
            append rc "            l = data.$name.length;" \n
            append rc "            dataOutputStream.writeInt(l);" \n
            append rc "            for (i = 0; i < l; i++) \{" \n
            append rc "                ba = $v(-builder-prefix)${childclass}(data.$name\[i\]);" \n
            append rc "                dataOutputStream.writeInt(ba.length);" \n
            append rc "                dataOutputStream.write(ba, 0, ba.length);" \n
            append rc "            \}" \n
        }
        list {
            set childclass [kdata::buildTitleName [kdata::getNameById [lindex $parameters 0]]]
            append rc "            l = data.$name.size();" \n
            append rc "            dataOutputStream.writeInt(l);" \n
            append rc "            for (i = 0; i < l; i++) \{" \n
            append rc "                ba = $v(-builder-prefix)${childclass}((${childclass}) data.$name.get(i));" \n
            append rc "                dataOutputStream.writeInt(ba.length);" \n
            append rc "                dataOutputStream.write(ba, 0, ba.length);" \n
            append rc "            \}" \n
        }
        primitivelist {
            set ptype [primitive2java [lindex $parameters 0]]
            append rc "            l = data.$name.size();" \n
            append rc "            dataOutputStream.writeInt(l);" \n
            append rc "            for (i = 0; i < l; i++) \{" \n
            switch -- [lindex $parameters 0] {
                int32 {
                    append rc "                dataOutputStream.writeInt(data.${name}.get(i));" \n
                }
            }
            append rc "            \}" \n
        }
        default {
            set ei "Unknown datatype \"$type\""
            return -code error -errorcode [list KDATAPARSER UNKNOWNDATATYPE] -errorinfo $ei $ei
        }
    }
    return $rc
}

proc kdata::java::builder_end {var} {
    upvar #0 $var v
    set rc ""
    append rc "        \}" \n
    append rc "        catch (IOException exception)  \{" \n
    if {$v(-create-comments)} {
        append rc \n "            /* Try closing DataOutputStream before thworing an error. */" \n
    }
    append rc "            if (dataOutputStream != null) \{" \n
    append rc "                try \{" \n
    append rc "                    dataOutputStream.close();" \n
    append rc "                \} catch (Exception e) \{\}" \n
    append rc "            \}" \n
    if {$v(-create-comments)} {
        append rc \n "            /* Try closing ByteArrayOutputStream before thworing an error. */" \n
    }
    append rc "            if (bytesOutputStream != null) \{" \n
    append rc "                try \{" \n
    append rc "                    bytesOutputStream.close();" \n
    append rc "                \} catch (Exception e) \{\}" \n
    append rc "            \}" \n
    append rc "            throw exception;" \n
    append rc "        \}" \n
    append rc "        retVal = bytesOutputStream.toByteArray();" \n
    if {$v(-create-comments)} {
        append rc \n "        /* Try closing DataOutputStream before returning. */" \n
    }
    append rc "        if (dataOutputStream != null) \{" \n
    append rc "            try \{" \n
    append rc "                dataOutputStream.close();" \n
    append rc "            \} catch (Exception e) \{\}" \n
    append rc "        \}" \n
    if {$v(-create-comments)} {
        append rc \n "        /* Try closing ByteArrayOutputStream before returning. */" \n
    }
    append rc "        if (bytesOutputStream != null) \{" \n
    append rc "            try \{" \n
    append rc "                bytesOutputStream.close();" \n
    append rc "            \} catch (Exception e) \{\}" \n
    append rc "        \}" \n
    append rc "        return retVal;" \n
    append rc "    \}" \n
    return $rc
}

# datatypes
proc kdata::java::datatype_begin {var name} {
    upvar #0 $var v
    set rc ""
    set v(_dtclass) [kdata::buildTitleName $name]
    append rc "" \n
    if {$v(-create-javadoc)} {
        append rc "    /**" \n
        append rc "     * Class for storing <i>$name</i> structure." \n
        append rc "     */" \n
    }
    append rc "    public static class $v(_dtclass) \{" \n
    append rc "" \n
    if {$v(-create-javadoc)} {
        append rc "        /**" \n
        append rc "         * Constructs an object." \n
        append rc "         */" \n
    }
    append rc "        public $v(_dtclass)() \{" \n
    append rc "        \}" \n
    return $rc
}

proc kdata::java::datatype_element {var type name default parameters} {
    upvar #0 $var v
    set rc ""
    array set dtype {byte byte int16 short int32 int int64 long}
    if {$v(-create-javadoc)} {
        append rc "" \n
        append rc "        /**" \n
        append rc "         * Kdata definition: type=\"$type\" name=\"$name\" parameters=\"$parameters\"" \n
        append rc "         */" \n
    }
    switch -- $type {
        element {
            # TODO: support initial values
            set childclass [kdata::buildTitleName [kdata::getNameById [lindex $parameters 0]]]
            append rc "        public $childclass $name = new ${childclass}();" \n
        }
        array {
            # TODO: support initial values
            set childclass [kdata::buildTitleName [kdata::getNameById [lindex $parameters 0]]]
            append rc "        public $childclass\[\] $name = new ${childclass}\[0\];" \n
        }
        list {
            # TODO: support initial values
            set childclass [kdata::buildTitleName [kdata::getNameById [lindex $parameters 0]]]
            append rc "        public ArrayList<$childclass> $name = new ArrayList<$childclass>();" \n
        }
        primitivelist {
            set ptype [primitive2java [lindex $parameters 0]]
            append rc "        public ArrayList<$ptype> $name = new ArrayList<$ptype>();" \n
        }
        bytearray {
            append rc "        public byte\[\] $name = new byte\[\] \{"
            set i 0; set e {}
            binary scan $default c* e
            foreach e $e {
                if {$i > 0} {
                    append rc ", $e"
                }  else  {
                    append rc $e
                }
                incr i
            }
            append rc "\};" \n
        }
        char {
            if {$default==""} {
                append rc "        public char $name;" \n
            }  else  {
                append rc "        public char $name = '$default';" \n
            }
        }
        string {
            # TODO: improve Java escaping
            set def [string map [list \n \\\n \r \\\r \\ \\\\ \" \\\"] $default]
            append rc "        public String $name = \"$def\";" \n
        }
        default {
            append rc "        public $dtype($type) $name = $default;" \n
        }
    }
    return $rc
}

proc kdata::java::datatype_end {var} {
    upvar #0 $var v
    set rc ""
    if {$v(-create-javadoc)} {
        append rc "" \n
        append rc "        /**" \n
        append rc "         * Generates an object from binary data." \n
        append rc "         *" \n
        append rc "         * @return object or null." \n
        append rc "         */" \n
    }
    append rc "        public static $v(_dtclass) $v(-parser-prefix)(byte\[\] data) \{" \n
    append rc "            $v(_dtclass) rc = null;" \n
    append rc "            try \{" \n
    append rc "                rc = $v(-parser-prefix)$v(_dtclass)(data);" \n
    append rc "            \} catch (IOException e) \{" \n
    append rc "            \}" \n
    append rc "            return rc;" \n
    append rc "        \}" \n\n

    if {$v(-create-javadoc)} {
        append rc "" \n
        append rc "        /**" \n
        append rc "         * Generates a binary data from an object." \n
        append rc "         *" \n
        append rc "         * @return binary data." \n
        append rc "         */" \n
    }
    append rc "        public byte\[\] $v(-builder-prefix)() \{" \n
    append rc "            byte\[\] rc = null;" \n
    append rc "            try \{" \n
    append rc "                rc = $v(-builder-prefix)$v(_dtclass)(this);" \n
    append rc "            \} catch (IOException e) \{" \n
    append rc "            \}" \n
    append rc "            return rc;" \n
    append rc "        \}" \n\n
    append rc "    \}" \n\n
    if {$v(-create-creator)} {
        if {$v(-create-javadoc)} {
            append rc "    /**" \n
            append rc "     * Creates a new <i>$v(_dtclass)</i> object." \n
            append rc "     */" \n
        }
        append rc "    public static $v(_dtclass) $v(-creator-prefix)$v(_dtclass)() \{" \n
        append rc "        return new $v(_dtclass)();" \n
        append rc "    \}" \n\n
    }
    return $rc
}

# structcalls
proc kdata::java::structcall_begin {var name} {
    upvar #0 $var v
    set rc ""
    return $rc
}

proc kdata::java::structcall_element {var type name default parameters} {
    upvar #0 $var v
    set rc ""
    return $rc
}

proc kdata::java::structcall_end {var} {
    upvar #0 $var v
    set rc ""
    return $rc
}

# multiplexer
proc kdata::java::multiplexer_code_begin {var} {
    upvar #0 $var v
    # parser code
    set v(_mxPcode) ""
    # receiver code
    set v(_mxRcode) ""
    # interface code
    set v(_mxIcode) ""
    # builder code
    set v(_mxBcode) ""
    set v(_first) true
    set rc ""
    return $rc
}

proc kdata::java::multiplexer_begin {var name} {
    upvar #0 $var v

    set first $v(_first)
    if {$first} {set v(_first) false}

    set rc ""
    set tn [kdata::buildTitleName $name]
    set un [kdata::buildUpperName $name]
    set id [kdata::getIdByName $name]
    
    set int "$v(-mxtype-prefix)_$un"
    
    if {$v(-create-javadoc)} {
        append rc "    /**" \n
        append rc "     * Constant identifying a <i>$name</i> structure when parsing multiple packages." \n
        append rc "     */" \n
    }
    append rc "    public final static int $int = $id;" \n
    
        if {$v(-create-javadoc)} {
            append v(_mxIcode) "        /**" \n
            append v(_mxIcode) "         * Method called when a <i>$name</i> package has been received." \n
            append v(_mxIcode) "         *" \n
            append v(_mxIcode) "         * @param data data received, as <i>$tn</i>." \n
            append v(_mxIcode) "         */" \n
        }
    append v(_mxIcode) "        public abstract void $v(-receiver-prefix)${tn}($tn data);" \n
    append v(_mxRcode) "case $int: \{" \n
    append v(_mxRcode) "    $tn pkgData = $v(-parser-prefix)${tn}(byteArray);" \n
    append v(_mxRcode) "    e = listenerHash.keys();" \n
    append v(_mxRcode) "    while (e.hasMoreElements()) \{" \n
    append v(_mxRcode) "        listener = (MessageListener) e.nextElement();" \n
    append v(_mxRcode) "        listener.$v(-receiver-prefix)${tn}(pkgData);" \n
    append v(_mxRcode) "    \}" \n
    append v(_mxRcode) "    break;" \n
    append v(_mxRcode) "\}" \n
    
    append v(_mxPcode) "case $int: \{" \n
    append v(_mxPcode) "    pkgData = $v(-parser-prefix)${tn}(byteArray);" \n
    append v(_mxPcode) "    break;" \n
    append v(_mxPcode) "\}" \n

    if {$v(-create-comments)} {
        append v(_mxBcode) "/* Try to send the message as $name, if it is such a class */" \n
    }
    if {$first} {
        append v(_mxBcode) "if (obj instanceof $tn) \{" \n
    }  else  {
        append v(_mxBcode) "else if (obj instanceof $tn) \{" \n
    }
    append v(_mxBcode) "    ab = (${v(-builder-prefix)}${tn}((${tn}) obj));" \n
    append v(_mxBcode) "    dos.writeInt($int);" \n
    append v(_mxBcode) "    dos.writeInt(ab.length);" \n
    append v(_mxBcode) "    dos.write(ab);" \n
    append v(_mxBcode) "\}" \n
    return $rc
}

proc kdata::java::multiplexer_element {var type name default parameters} {
    upvar #0 $var v
    set rc ""
    return $rc
}

proc kdata::java::multiplexer_end {var} {
    upvar #0 $var v
    set rc ""
    return $rc
}

proc kdata::java::multiplexer_code_end {var} {
    upvar #0 $var v
    set rc ""
    
    if {$v(-create-mx-receiver)} {
        if {$v(-create-javadoc)} {
            append rc "    /**" \n
            append rc "     * Interface for broadcasting message received events." \n
            append rc "     */" \n
        }
        append rc "    public interface MessageListener \{" \n
        if {$v(-create-javadoc)} {
            append rc "        /**" \n
            append rc "         * Method called when an unknown package has been received." \n
            append rc "         *" \n
            append rc "         * @param pkgId ID of the package received." \n
            append rc "         * @param data binary data received." \n
            append rc "         */" \n
        }
        append rc "        public abstract void $v(-receiver-prefix)Unknown(int pkgId, byte\[\] data);" \n
        append rc $v(_mxIcode)
        append rc "    \}" \n\n
    
        append rc "    private Hashtable<MessageListener,MessageListener> listenerHash = new Hashtable<MessageListener,MessageListener>();" \n
        if {$v(-create-javadoc)} {
            append rc "    /**" \n
            append rc "     * Adds the specified message listener to receive events on new packages received." \n
            append rc "     *" \n
            append rc "     * @param listener the message listener." \n
            append rc "     */" \n
        }
        append rc "    public void addListener(MessageListener listener) \{" \n
        append rc "        listenerHash.put(listener, listener);" \n
        append rc "    \}" \n\n
    
        if {$v(-create-javadoc)} {
            append rc "    /**" \n
            append rc "     * Removes the specified message listener so that it no longer receives events on new packages received." \n
            append rc "     *" \n
            append rc "     * @param listener the message listener." \n
            append rc "     */" \n
        }
        append rc "    public void removeListener(MessageListener listener) \{" \n
        append rc "        listenerHash.remove(listener);" \n
        append rc "    \}" \n\n
    
        if {$v(-create-javadoc)} {
            append rc "    /**" \n
            append rc "     * Tries to fetch packages from binary data and broadcast them to all bound listeners." \n
            append rc "     *" \n
            append rc "     * @param data binary data containing 0 or more packages to be parsed and broadcasted." \n
            append rc "     */" \n
        }
        append rc "    public int receivePackages(byte\[\] data) \{" \n
        append rc "        int retVal = 0;" \n
        append rc "        ByteArrayInputStream bis = new ByteArrayInputStream(data);" \n
        append rc "        retVal = receivePackages(bis);" \n
        append rc "        try \{" \n
        append rc "            bis.close();" \n
        append rc "        \} catch (Exception exception) \{\}" \n
        append rc "        return(retVal);" \n
        append rc "    \}" \n\n
    
        if {$v(-create-javadoc)} {
            append rc "    /**" \n
            append rc "     * Tries to fetch packages from binary data and broadcast them to all bound listeners." \n
            append rc "     *" \n
            append rc "     * @param data InputStream that will be used to read binary data." \n
            append rc "     */" \n
        }
        append rc "    public int receivePackages(InputStream data) \{" \n
        append rc "        int retVal = 0;" \n
        append rc "        DataInputStream dis = new DataInputStream(data);" \n
        append rc "        retVal = receivePackages((DataInput) dis);" \n
        append rc "        try \{" \n
        append rc "            dis.close();" \n
        append rc "        \} catch (Exception exception) \{\}" \n
        append rc "        return(retVal);" \n
        append rc "    \}" \n\n
    
        if {$v(-create-javadoc)} {
            append rc "    /**" \n
            append rc "     * Tries to fetch packages from binary data and broadcast them to all bound listeners." \n
            append rc "     *" \n
            append rc "     * @param data DataInput that will be used to read binary data." \n
            append rc "     */" \n
        }
        append rc "    public int receivePackages(DataInput data) \{" \n
        append rc "        int retVal = 0;" \n
        append rc "        int pkgId, pkgSize, i, l;" \n
        append rc "        byte\[\] byteArray;" \n
        append rc "        Enumeration<MessageListener> e;" \n
        append rc "        MessageListener listener;" \n
        append rc "        try \{" \n
        append rc "            l = data.readInt();" \n
        append rc "            for (i = 0; i < l; i++) \{" \n
        append rc "                pkgId = data.readInt();" \n
        append rc "                pkgSize = data.readInt();" \n
        append rc "                byteArray = new byte\[pkgSize\];" \n
        append rc "                data.readFully(byteArray);" \n
        append rc "                switch (pkgId) \{" \n
        set space "                    "
        append rc $space [join [split $v(_mxRcode) \n] "\n${space}"] \n
        append rc "                    default:" \n
        append rc "                        e = listenerHash.keys();" \n
        append rc "                        while (e.hasMoreElements()) \{" \n
        append rc "                            listener = (MessageListener) e.nextElement();" \n
        append rc "                            listener.$v(-receiver-prefix)Unknown(pkgId, byteArray);" \n
        append rc "                        \}" \n
        append rc "                        break;" \n
        append rc "                \}" \n
        append rc "                retVal++;" \n
        append rc "            \}" \n
        append rc "        \}" \n
        append rc "        catch (IOException exception) \{" \n
        append rc "        \}" \n
        append rc "        return(retVal);" \n
        append rc "    \}" \n\n
    }

    if {$v(-create-mx-parser)} {
        # array version
        if {$v(-create-javadoc)} {
            append rc "    /**" \n
            append rc "     * Tries to fetch packages from binary data and return them as an array of objects." \n
            append rc "     *" \n
            append rc "     * @param data binary data containing 0 or more packages to be parsed." \n
            append rc "     */" \n
        }
        append rc "    public static Object\[\] parsePackagesToArray(byte\[\] data) \{" \n
        append rc "        Object\[\] retVal = null;" \n
        append rc "        ByteArrayInputStream bis = new ByteArrayInputStream(data);" \n
        append rc "        retVal = parsePackagesToArray(bis);" \n
        append rc "        try \{" \n
        append rc "            bis.close();" \n
        append rc "        \} catch (Exception exception) \{\}" \n
        append rc "        return(retVal);" \n
        append rc "    \}" \n\n
    
        if {$v(-create-javadoc)} {
            append rc "    /**" \n
            append rc "     * Tries to fetch packages from binary data and return them as an array of objects." \n
            append rc "     *" \n
            append rc "     * @param data InputStream that will be used to read binary data." \n
            append rc "     */" \n
        }
        append rc "    public static Object\[\] parsePackagesToArray(InputStream data) \{" \n
        append rc "        Object\[\] retVal = null;" \n
        append rc "        DataInputStream dis = new DataInputStream(data);" \n
        append rc "        retVal = parsePackagesToArray((DataInput) dis);" \n
        append rc "        try \{" \n
        append rc "            dis.close();" \n
        append rc "        \} catch (Exception exception) \{\}" \n
        append rc "        return(retVal);" \n
        append rc "    \}" \n\n
    
        if {$v(-create-javadoc)} {
            append rc "    /**" \n
            append rc "     * Tries to fetch packages from binary data and return them as an array of objects." \n
            append rc "     *" \n
            append rc "     * @param data DataInput that will be used to read binary data." \n
            append rc "     */" \n
        }
        append rc "    public static Object\[\] parsePackagesToArray(DataInput data) \{" \n
        append rc "        Object\[\] retVal = new Object\[0\];" \n
        append rc "        Object pkgData;" \n
        append rc "        int pkgId, pkgSize, i = 0, l;" \n
        append rc "        byte\[\] byteArray;" \n
        append rc "        MessageListener listener;" \n
        append rc "        try \{" \n
        append rc "            l = data.readInt();" \n
        append rc "            for (i = 0; i < l; i++) \{" \n
        append rc "                pkgId = data.readInt();" \n
        append rc "                pkgSize = data.readInt();" \n
        append rc "                byteArray = new byte\[pkgSize\];" \n
        append rc "                data.readFully(byteArray);" \n
        append rc "                pkgData = null;" \n
        append rc "                switch (pkgId) \{" \n
        set space "                    "
        append rc $space [join [split $v(_mxPcode) \n] "\n${space}"] \n
        append rc "                \}" \n
        append rc "                retVal\[i\] = pkgData;" \n
        append rc "            \}" \n
        append rc "        \}" \n
        append rc "        catch (IOException exception) \{" \n
        append rc "            Object\[\] tmp = new Object\[i\];" \n
        append rc "            System.arraycopy(retVal, 0, tmp, 0, i);" \n
        append rc "            retVal = tmp;" \n
        append rc "        \}" \n
        append rc "        return(retVal);" \n
        append rc "    \}" \n\n

        # vector version
        if {$v(-create-javadoc)} {
            append rc "    /**" \n
            append rc "     * Tries to fetch packages from binary data and return them as a vector." \n
            append rc "     *" \n
            append rc "     * @param data binary data containing 0 or more packages to be parsed." \n
            append rc "     */" \n
        }
        append rc "    public static ArrayList<Object> parsePackagesToArrayList(byte\[\] data) \{" \n
        append rc "        ArrayList<Object> retVal;" \n
        append rc "        ByteArrayInputStream bis = new ByteArrayInputStream(data);" \n
        append rc "        retVal = parsePackagesToArrayList(bis);" \n
        append rc "        try \{" \n
        append rc "            bis.close();" \n
        append rc "        \} catch (Exception exception) \{\}" \n
        append rc "        return(retVal);" \n
        append rc "    \}" \n\n
    
        if {$v(-create-javadoc)} {
            append rc "    /**" \n
            append rc "     * Tries to fetch packages from binary data and return them as a vector." \n
            append rc "     *" \n
            append rc "     * @param data InputStream that will be used to read binary data." \n
            append rc "     */" \n
        }
        append rc "    public static ArrayList<Object> parsePackagesToArrayList(InputStream data) \{" \n
        append rc "        ArrayList<Object> retVal;" \n
        append rc "        DataInputStream dis = new DataInputStream(data);" \n
        append rc "        retVal = parsePackagesToArrayList((DataInput) dis);" \n
        append rc "        try \{" \n
        append rc "            dis.close();" \n
        append rc "        \} catch (Exception exception) \{\}" \n
        append rc "        return(retVal);" \n
        append rc "    \}" \n\n
    
        if {$v(-create-javadoc)} {
            append rc "    /**" \n
            append rc "     * Tries to fetch packages from binary data and return them as a vector." \n
            append rc "     *" \n
            append rc "     * @param data DataInput that will be used to read binary data." \n
            append rc "     */" \n
        }
        append rc "    public static ArrayList<Object> parsePackagesToArrayList(DataInput data) \{" \n
        append rc "        ArrayList<Object> retVal = new ArrayList<Object>();" \n
        append rc "        Object pkgData;" \n
        append rc "        int pkgId, pkgSize, i = 0, l;" \n
        append rc "        byte\[\] byteArray;" \n
        append rc "        MessageListener listener;" \n
        append rc "        try \{" \n
        append rc "            l = data.readInt();" \n
        append rc "            for (i = 0; i < l; i++) \{" \n
        append rc "                pkgId = data.readInt();" \n
        append rc "                pkgSize = data.readInt();" \n
        append rc "                byteArray = new byte\[pkgSize\];" \n
        append rc "                data.readFully(byteArray);" \n
        append rc "                pkgData = null;" \n
        append rc "                switch (pkgId) \{" \n
        set space "                    "
        append rc $space [join [split $v(_mxPcode) \n] "\n${space}"] \n
        append rc "                \}" \n
        append rc "                retVal.add(pkgData);" \n
        append rc "            \}" \n
        append rc "        \}" \n
        append rc "        catch (IOException exception) \{" \n
        append rc "        \}" \n
        append rc "        return(retVal);" \n
        append rc "    \}" \n\n
    }

    if {$v(-create-mx-builder)} {
        # array versions
        if {$v(-create-javadoc)} {
            append rc "    /**" \n
            append rc "     * Converts multiple objects to binary data." \n
            append rc "     * " \n
            append rc "     * @param packages an array of packages to create." \n
            append rc "     * @return an array of bytes with the binary data." \n
            append rc "     */" \n
        }
        append rc "    public static byte\[\] buildPackages(Object\[\] packages) \{" \n
        append rc "        byte\[\] retVal = null;" \n
        append rc "        ByteArrayOutputStream bos = new ByteArrayOutputStream();" \n
        append rc "        if (buildPackages(packages, bos)) \{" \n
        append rc "            retVal = bos.toByteArray();" \n
        append rc "        \}" \n
        append rc "        try \{" \n
        append rc "            bos.close();" \n
        append rc "        \} catch (Exception exception) \{\}" \n
        append rc "        return retVal;" \n
        append rc "    \}" \n\n
        
        if {$v(-create-javadoc)} {
            append rc "    /**" \n
            append rc "     * Writes multiple objects to a stream." \n
            append rc "     * " \n
            append rc "     * @param packages an array of packages to create." \n
            append rc "     * @param stream OutputStream to write to." \n
            append rc "     * @return whether building has succeeded or not." \n
            append rc "     */" \n
        }
        append rc "    public static boolean buildPackages(Object\[\] packages, OutputStream stream) \{" \n
        append rc "        boolean retVal = false;" \n
        append rc "        DataOutputStream dos = new DataOutputStream(stream);" \n
        append rc "        try \{" \n
        append rc "            retVal = buildPackages(packages, (DataOutput) dos);" \n
        append rc "        \} catch (Exception exception) \{\}" \n
        append rc "        try \{" \n
        append rc "            dos.close();" \n
        append rc "        \} catch (Exception exception) \{\}" \n
        append rc "        return(retVal);" \n
        append rc "    \}" \n\n
        
        if {$v(-create-javadoc)} {
            append rc "    /**" \n
            append rc "     * Writes multiple objects to a stream." \n
            append rc "     * " \n
            append rc "     * @param packages an array of packages to create." \n
            append rc "     * @param stream DataOutput to write to." \n
            append rc "     * @return whether building has succeeded or not." \n
            append rc "     */" \n
        }
        append rc "    public static boolean buildPackages(Object\[\] packages, DataOutput stream) throws IOException \{" \n
        append rc "        int i, j, k, l;" \n
        append rc "        DataOutput dos = stream;" \n
        append rc "        Object obj;" \n
        append rc "        byte\[\] ab;" \n
        append rc "        l = packages.length;" \n
        append rc "        dos.writeInt(l);" \n
        append rc "        for (i = 0; i < l; i++) \{" \n
        append rc "            obj = packages\[i\];" \n
        set space "            "
        append rc $space [join [split $v(_mxBcode) \n] "\n${space}"] \n
        append rc "            else  \{" \n
        append rc "                /* TODO: handle unknown datatypes */" \n
        append rc "            \}" \n
        append rc "        \}" \n
        append rc "        return true;" \n
        append rc "    \}" \n\n
        
        # vector versions
        if {$v(-create-javadoc)} {
            append rc "    /**" \n
            append rc "     * Converts multiple objects to binary data." \n
            append rc "     * " \n
            append rc "     * @param packages a vector of packages to create." \n
            append rc "     * @return an array of bytes with the binary data." \n
            append rc "     */" \n
        }
        append rc "    public static byte\[\] buildPackages(ArrayList<Object> packages) \{" \n
        append rc "        byte\[\] retVal = null;" \n
        append rc "        ByteArrayOutputStream bos = new ByteArrayOutputStream();" \n
        append rc "        if (buildPackages(packages, bos)) \{" \n
        append rc "            retVal = bos.toByteArray();" \n
        append rc "        \}" \n
        append rc "        try \{" \n
        append rc "            bos.close();" \n
        append rc "        \} catch (Exception exception) \{\}" \n
        append rc "        return retVal;" \n
        append rc "    \}" \n\n
        
        if {$v(-create-javadoc)} {
            append rc "    /**" \n
            append rc "     * Writes multiple objects to a stream." \n
            append rc "     * " \n
            append rc "     * @param packages a vector of packages to create." \n
            append rc "     * @param stream OutputStream to write to." \n
            append rc "     * @return whether building has succeeded or not." \n
            append rc "     */" \n
        }
        append rc "    public static boolean buildPackages(ArrayList<Object> packages, OutputStream stream) \{" \n
        append rc "        boolean retVal = false;" \n
        append rc "        DataOutputStream dos = new DataOutputStream(stream);" \n
        append rc "        try \{" \n
        append rc "            retVal = buildPackages(packages, (DataOutput) dos);" \n
        append rc "        \} catch (Exception exception) \{\}" \n
        append rc "        try \{" \n
        append rc "            dos.close();" \n
        append rc "        \} catch (Exception exception) \{\}" \n
        append rc "        return(retVal);" \n
        append rc "    \}" \n\n
        
        if {$v(-create-javadoc)} {
            append rc "    /**" \n
            append rc "     * Writes multiple objects to a stream." \n
            append rc "     * " \n
            append rc "     * @param packages a vector of packages to create." \n
            append rc "     * @param stream DataOutput to write to." \n
            append rc "     * @return whether building has succeeded or not." \n
            append rc "     */" \n
        }
        append rc "    public static boolean buildPackages(ArrayList<Object> packages, DataOutput stream) throws IOException \{" \n
        append rc "        int i, j, k, l;" \n
        append rc "        DataOutput dos = stream;" \n
        append rc "        Object obj;" \n
        append rc "        byte\[\] ab;" \n
        append rc "        l = packages.size();" \n
        append rc "        dos.writeInt(l);" \n
        append rc "        for (i = 0; i < l; i++) \{" \n
        append rc "            obj = packages.get(i);" \n
        set space "            "
        append rc $space [join [split $v(_mxBcode) \n] "\n${space}"] \n
        append rc "            else  \{" \n
        append rc "                /* TODO: handle unknown datatypes */" \n
        append rc "            \}" \n
        append rc "        \}" \n
        append rc "        return true;" \n
        append rc "    \}" \n\n
    }

    return $rc
}

proc kdata::java::enum_begin {var name} {
    upvar #0 $var v
    set rc ""
    append rc "" \n
    if {$v(-create-javadoc)} {
    append rc "    /**" \n
    append rc "     * Class for storing $name enumeration." \n
    append rc "     */" \n
    }
    append rc "    public static class [kdata::buildTitleName $name] \{" \n
    append rc "" \n
    return $rc
}

proc kdata::java::enum_value {var enumName enumVKey enumValue} {
    upvar #0 $var v
    set rc ""
    if {$v(-create-javadoc)} {
    append rc "        /**" \n
    append rc "         * Enumeration $enumName value $enumVKey" \n
    append rc "         */" \n
    }
    append rc "        public static final int [kdata::buildUpperName $enumVKey] = $enumValue;" \n
    return $rc
}

proc kdata::java::enum_end {var name} {
    upvar #0 $var v
    set rc ""
    append rc "    \}" \n
    append rc "" \n
    return $rc
}

package provide kdata::language::java 1.0
