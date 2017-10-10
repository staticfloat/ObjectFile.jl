export MachHeader, MachHeader32, MachHeader64, MachFatArch, MachFatHeader

"""
    MachHeader

Mach-O Header type, containing metadata about the Mach object itself, such as
its CPU target, the number of Load Commands within the file, etc...
"""
abstract type MachOHeader{H <: ObjectHandle} end

@io immutable MachOHeader32{H <: ObjectHandle} <: MachOHeader{H}
    magic::UInt32
    cputype::UInt32
    cpusubtype::UInt32
    filetype::UInt32
    ncmds::UInt32
    sizeofcmds::UInt32
    flags::UInt32
end

@io immutable MachOHeader64{H <: ObjectHandle} <: MachOHeader{H}
    magic::UInt32
    cputype::UInt32
    cpusubtype::UInt32
    filetype::UInt32
    ncmds::UInt32
    sizeofcmds::UInt32
    flags::UInt32
    reserved::UInt32
end

"""
    macho_header_type(magic::UInt32)

Given the `magic` field from a Mach-O file header, return the type of the
Mach-O header.
"""
function macho_header_type(magic::UInt32)
    if magic in (MH_MAGIC, MH_CIGAM)
        return MachOHeader32{MachOHandle}
    elseif magic in (MH_MAGIC_64, MH_CIGAM_64)
        return MachOHeader64{MachOHandle}
    elseif magic in (FAT_MAGIC, FAT_CIGAM)
        return MachOFatHeader{MachOHandle}
    else
        throw(MagicMismatch("Invalid Magic ($(hex(magic)))!"))
    end
end

"""
    macho_is64bit(magic::UInt32)

Given the `magic` field from a Mach-O file header, return the bitwidth of the
Mach-O header.
"""
function macho_is64bit(magic::UInt32)
    if magic in (MH_MAGIC_64, MH_CIGAM_64)
        return true
    elseif magic in (MH_MAGIC, MH_CIGAM, FAT_MAGIC, FAT_CIGAM)
        return false
    else
        throw(MagicMismatch("Invalid Magic ($(hex(magic)))!"))
    end
end

"""
    macho_endianness(magic::UInt32)

Given the `magic` field from a Mach-O file header, return the endianness of the
Mach-O header.
"""
function macho_endianness(magic::UInt32)
    if magic in (MH_CIGAM, MH_CIGAM_64, FAT_CIGAM)
        return :BigEndian
    elseif magic in (MH_MAGIC, MH_MAGIC_64, FAT_MAGIC)
        return :LittleEndian
    else
        throw(MagicMismatch("Invalid Magic ($(hex(magic)))!"))
    end
end