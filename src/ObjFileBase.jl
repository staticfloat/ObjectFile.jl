module ObjFileBase

export ObjectHandle, SectionRef, SymbolRef, debugsections

export printfield, printentry, printfield_with_color, deref,
    sectionaddress, sectionoffset, sectionsize, sectionname,
    load_strtab, readmeta

import Base: read, seek, readbytes, position, show

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

# The address of the section in virtual memory
@mustimplement sectionaddress(section::Section)

# The name of the section
@mustimplement sectionname(section::SectionRef)

# Retrieving the actual section datastructure
@mustimplement deref(section::SectionRef)

# Retrieving the object handle
@mustimplement handle(section::SectionRef)

abstract SymbolRef{T<:ObjectHandle}
abstract SymtabEntry{T<:ObjectHandle}

sectionsize(x::SectionRef) = sectionsize(deref(x))
sectionaddress(x::SectionRef) = sectionaddress(deref(x))
sectionoffset(x::SectionRef) = sectionoffset(deref(x))

handleT{T}(::Union(Type{SectionRef{T}}, Type{Section{T}}, Type{SymbolRef{T}},
    Type{SymtabEntry{T}})) = T

abstract StrTab

function load_strtab
end
@mustimplement strtab_lookup(s::StrTab, offset)

################################# Utilities ####################################

typealias SectionOrRef{T} Union(Section{T},SectionRef{T})

sectionsize(sect::SectionRef) = sectionsize(deref(sect))
sectionoffset(sect::SectionRef) = sectionoffset(deref(sect))

seek{T<:ObjectHandle,S}(oh::T, section::Section{S}) =
    (@assert T <: S; seek(oh,sectionoffset(section)))

seek(section::SectionRef) = seek(handle(section), deref(section))

function readbytes{T<:ObjectHandle,S}(oh::T,sec::Section{S})
    @assert T <: S
    seek(oh, sec)
    readbytes(oh, sectionsize(sec))
end
readbytes(sec::SectionRef) = readbytes(handle(sec),deref(sec))

typealias Maybe{T} Union(T,Nothing)

# # # Higher level debug info support
immutable DebugSections{T<:ObjectHandle, Sect}
    oh::T
    debug_abbrev::Maybe{Sect}
    debug_aranges::Maybe{Sect}
    debug_frame::Maybe{Sect}
    debug_info::Maybe{Sect}
    debug_line::Maybe{Sect}
    debug_loc::Maybe{Sect}
    debug_macinfo::Maybe{Sect}
    debug_pubnames::Maybe{Sect}
    debug_ranges::Maybe{Sect}
    debug_str::Maybe{Sect}
    debug_types::Maybe{Sect}

end

function DebugSections{T}(oh::T; debug_abbrev = nothing, debug_aranges = nothing,
    debug_frame = nothing, debug_info = nothing, debug_line = nothing,
    debug_macinfo = nothing, debug_pubnames = nothing, debug_loc= nothing,
    debug_ranges = nothing, debug_str = nothing, debug_types = nothing)
    DebugSections(oh, debug_abbrev, debug_aranges, debug_frame, debug_info,
        debug_line, debug_loc, debug_macinfo, debug_pubnames, debug_ranges,
        debug_str, debug_types)
end

function DebugSections{T<:ObjectHandle}(oh::T, sections::Dict)
    DebugSections(oh,
        debug_abbrev = get(sections, "debug_abbrev", nothing),
        debug_aranges = get(sections, "debug_aranges", nothing),
        debug_frame = get(sections, "debug_frame", nothing),
        debug_info = get(sections, "debug_info", nothing),
        debug_line = get(sections, "debug_line", nothing),
        debug_loc = get(sections, "debug_loc", nothing),
        debug_macinfo = get(sections, "debug_macinfo", nothing),
        debug_pubnames = get(sections, "debug_pubnames", nothing),
        debug_ranges = get(sections, "debug_ranges", nothing),
        debug_str = get(sections, "debug_str", nothing),
        debug_types = get(sections, "debug_types", nothing))
end

function show(io::IO, dsect::DebugSections)
    println(io, "Debug Sections for $(dsect.oh)")
    println(io,"========================= debug_abbrev =========================")
    println(io,dsect.debug_abbrev)
    println(io,"======================== debug_aranges =========================")
    println(io,dsect.debug_aranges)
    println(io,"========================= debug_frame ==========================")
    println(io,dsect.debug_frame)
    println(io,"========================= debug_info ===========================")
    println(io,dsect.debug_info)
    println(io,"========================= debug_line ===========================")
    println(io,dsect.debug_line)
    println(io,"========================== debug_loc ===========================")
    println(io,dsect.debug_loc)
    println(io,"======================== debug_macinfo =========================")
    println(io,dsect.debug_macinfo)
    println(io,"======================= debug_pubnames =========================")
    println(io,dsect.debug_pubnames)
    println(io,"======================== debug_ranges ==========================")
    println(io,dsect.debug_ranges)
    println(io,"=========================== debug_str ==========================")
    println(io,dsect.debug_str)
    println(io,"========================= debug_types ==========================")
    println(io,dsect.debug_types)
end

@mustimplement debugsections(oh::ObjectHandle)

export findindexbyname, findcubyname

function findindexbyname
end

function findcubyname
end

# Utils
# JIT Utils

function is_jit_section(s::Section)
    sectionaddress(s) > 0x100000
end
is_jit_section(s::SectionRef) = is_jit_section(deref(s))

@mustimplement replace_sections_from_memory(h::ObjectHandle, buffer)

# Printing utils
function printfield(io::IO,string,fieldlength; align = :right)
    (align == :right) && print(io," "^max(fieldlength-length(string),0))
    print(io,string)
    (align == :left) && print(io," "^max(fieldlength-length(string),0))
end
function printfield_with_color(color,io::IO,string,fieldlength; align = :right)
    (align == :right) && print(io," "^max(fieldlength-length(string),0))
    print_with_color(color,io,string)
    (align == :left) && print(io," "^max(fieldlength-length(string),0))
end
printentry(io::IO,header,values...) = (printfield(io,header,21);println(io," ",values...))

# User facing interfaces

immutable MagicMismatch;
    message
end

function readmeta(io::IO)
    ts = subtypes(ObjFileBase.ObjectHandle)
    pos = position(io)
    for T in ts
        seek(io,pos)
        try
            return readmeta(io, T)
        catch e
            if !isa(e,MagicMismatch)
                rethrow(e)
            end
        end
    end
    error("""
        Object file is not any of $(join(ts, ", "))!
        To force one object file use readmeta(io,T).
        If the format you want is not listed, make sure
        the appropriate pacakge is loaded before calling
        this function.
        """)
end

readmeta(file::String) = readmeta(open(file,"r"))

# Others

function getSectionLoadAddress
end

end # module
