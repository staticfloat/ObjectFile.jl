export ELFHeader, ELFHeader32, ELFHeader64

import Base: show

"""
    ELFHeader

ELF Header type, containing metadata about the ELF object itself, such as its
type, offsets for the Program and Section headers, the number of other header
entries, etc...
"""
abstract type ELFHeader{H <: ObjectHandle} end
@io struct ELFHeader32{H <: ObjectHandle} <: ELFHeader{H}
    e_type::UInt16
    e_machine::UInt16
    e_version::UInt32
    e_entry::UInt32
    e_phoff::UInt32
    e_shoff::UInt32
    e_flags::UInt32
    e_ehsize::UInt16
    e_phentsize::UInt16
    e_phnum::UInt16
    e_shentsize::UInt16
    e_shnum::UInt16
    e_shstrndx::UInt16
end
@io struct ELFHeader64{H <: ObjectHandle} <: ELFHeader{H}
    e_type::UInt16
    e_machine::UInt16
    e_version::UInt32
    e_entry::UInt64
    e_phoff::UInt64
    e_shoff::UInt64
    e_flags::UInt32
    e_ehsize::UInt16
    e_phentsize::UInt16
    e_phnum::UInt16
    e_shentsize::UInt16
    e_shnum::UInt16
    e_shstrndx::UInt16
end

function show(io::IO, header::ELFHeader)
    printentry(io,"Type",filetype(header.e_type))
    printentry(io,"Machine",machinetype(header.e_machine))
    # Skip e_version (not particularly useful)
    printentry(io,"Entrypoint","0x",hex(header.e_entry))
    printentry(io,"PH Offset","0x",hex(header.e_phoff))
    printentry(io,"SH Offset","0x",hex(header.e_shoff))
    # Skip flags
    printentry(io,"Header Size","0x",hex(header.e_ehsize))
    printentry(io,"PH Entry Size","0x",hex(header.e_phentsize))
    printentry(io,"PH Entry Count",dec(header.e_phnum))
    printentry(io,"SH Entry Size","0x",hex(header.e_shentsize))
    printentry(io,"SH Entry Count",dec(header.e_shnum))
    printentry(io,"Strtab Index",dec(header.e_shstrndx))
end

function filetype(e_type)
    if haskey(ET_TYPES, e_type)
        return ET_TYPES[e_type]
    end
    return string("Unknown (0x",hex(e_type),")")
end


function machinetype(e_machine)
    if haskey(EM_MACHINES, e_machine)
        return EM_MACHINES[e_machine]
    end
    return string("Unknown (0x",hex(e_machine),")")
end
