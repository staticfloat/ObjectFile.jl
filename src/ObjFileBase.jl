module ObjFileBase

export ObjectHandle, SectionRef, SymbolRef

import Base: read, seek, readbytes, position

########## ObjFileBase.jl - Basic shared functionality for all object files ####
#
#   This package provides basic functionality that is shared among object files.
#   It was written with ELF/MachO/COFF in mind, but should be easily adaptable
#   to other object files as well.
#
#   The family of Object file implementations have a somewhat different focus than
#   a lot of other ones. While certainly usable to write a linker or compiler,
#   they are more intended for interactive exploration and verification and some
#   of the design choices reflect this. Nevertheless, this does not mean that
#   performance should be unnecessarily compromised.
#
# # # Basic Concepts
#
# # ObjectHandle
#
#   Provides an abstraction over a specific instance of the object file.
#   Currently many implementations put the IO object to be read from in this
#   handle, which has proven convenient for interactive usage.
#
# # SectionIterator, SymbolIterator, etc.
#
#   Provides support for iterating over Symbols, Sections, Relocations, etc.
#   These should have a reference to the original ObjectHandle and read the
#   desired information on demand. Rather than returning the read datastructure
#   directly, it should return in in an appropriate *Ref object.
#
# # SetionRef, SymbolRef
#
#   Convenience objects (mostly for interactive usage) that contain a reference
#   to the original object handle as well as any information that may be needed
#   to get further information about the Referenced object that is not
#   explicitly encoded in the data structure itself. Examples may include:
#
#       - Offset in the file (especially for variable length records
#            where only the header is part of the datastructure)
#       - Symbol/Section index
#       - Etc.
#
################################################################################

# # # Tools

macro mustimplement(sig)
    fname = sig.args[1]
    arg1 = sig.args[2]
    if isa(arg1,Expr)
        arg1 = arg1.args[1]
    end
    :($(esc(sig)) = error(typeof($(esc(arg1))),
                          " must implement ", $(Expr(:quote,fname))))
end

################################# Interfaces ###################################

# # # ObjectHandle

abstract ObjectHandle

# External facing interface
readmeta{T<:ObjectHandle}(io::IO, ::Type{T}) =
    error("$T must register a readmeta method")

@mustimplement readheader(oh::ObjectHandle)

# Querying general properties
@mustimplement endianness(oh::ObjectHandle)

# ObjectHandle IO interface
@mustimplement seek(oh::ObjectHandle, args...)
@mustimplement position(oh::ObjectHandle)

##
#  These are parameterized on the type of Object Handle. An imaginary Foo
#  fileformat might declare:
#
#   module Foo
#       immutable FooHandle; ... end
#       immutable Section <: ObjFileBase.Section{FooHandle}
#       ...; end
#   end
##

abstract SectionRef{T<:ObjectHandle}
abstract Section{T<:ObjectHandle}

# The size of the actual data contained in the section. This should exclude any
# padding mandated by the file format e.g. due to alignment rules
@mustimplement sectionsize(section::Section)

# The offset of the section in the file
@mustimplement sectionoffset(section::Section)

# Retrieving the actual section datastructure
@mustimplement deref(section::SectionRef)

# Retrieving the object handle
@mustimplement handle(section::SectionRef)

abstract SymbolRef{T<:ObjectHandle}
abstract SymtabEntry{T<:ObjectHandle}

################################# Utilities ####################################

typealias SectionOrRef{T} Union(Section{T},SectionRef{T})

sectionsize(sect::SectionRef) = sectionsize(deref(sect))
sectionoffset(sect::SectionRef) = sectionoffset(deref(sect))

seek{T<:ObjectHandle}(oh::T, section::Section{T}) =
    seek(oh,sectionoffset(section))

seek(section::SectionRef) = seek(handle(section), deref(section))

function readbytes{T<:ObjectHandle}(oh::T,sec::Section{T})
    seek(oh, sec)
    readbytes(oh, sectionsize(sec))
end
readbytes(sec::SectionRef) = readbytes(handle(sec),deref(sec))

# # # DWARF support
#
#   Whether or not this is the right place to put this is up for debate, but
#   this way, DWARF does not need to be concerned with the specific notion of
#   being embedded in an object file.
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

using DWARF

@mustimplement debugsections(oh::ObjectHandle)

function read{T<:ObjectHandle}(oh::T,sec::Section{T},::Type{DWARF.ARTable})
    seek(oh, sec)
    ret = DWARF.ARTable(Array(DWARF.ARTableSet,0))
    while position(oh) < sectionoffset(sec) + sectionsize(sec)
        push!(ret.sets, read(oh, DWARF.ARTableSet, endianness(oh)))
    end
    ret
end

function read{T<:ObjectHandle}(oh::T,sec::Section{T},::Type{DWARF.PUBTable})
    seek(oh, sec)
    ret = DWARF.PUBTable(Array(DWARF.PUBTableSet,0))
    while position(oh) < sectionoffset(sec) + sectionsize(sec)
        push!(ret.sets,read(oh,DWARF.PUBTableSet, endianness(oh)))
    end
    ret
end

function read{T<:ObjectHandle}(oh::T, sec::Section{T},
        ::Type{DWARF.AbbrevTableSet})
    seek(oh, sec)
    read(oh, AbbrevTableSet, endianness(oh))
end

function read{T<:ObjectHandle}(oh::T,sec::Section{T},
        s::DWARF.PUBTableSet,::Type{DWARF.DWARFCUHeader})

    seek(oh,sectionoffsect(debug_info)+s.header.debug_info_offset)
    read(oh,DWARF.DWARFCUHeader, endianness(oh))
end

function read{T<:ObjectHandle}(oh::T, sec::Section{T}, s::DWARF.DWARFCUHeader,
        ::Type{DWARF.AbbrevTableSet})

    seek(oh,sectionoffsect(debug_info)+s.debug_abbrev_offset)
    read(oh,DWARF.AbbrevTableSet, endianness(oh))
end

function read{T<:ObjectHandle}(oh::T,
    debug_info::Section{T}, debug_abbrev::Section{T},
    s::DWARF.PUBTableSet, e::DWARF.PUBTableEntry,
    header::DWARF.DWARFCUHeader, ::Type{DWARF.DIETree})

    ats = read(oh,debug_abbrev,header,DWARF.AbbrevTableSet)
    seek(oh,sectionoffset(offset)+s.header.debug_info_offset+e.offset)
    ret = DWARF.DIETree(Array(DWARF.DIETreeNode,0))
    read(oh,header,ats,ret,DWARF.DIETreeNode,:LittleEndian)
    ret
end

end # module
