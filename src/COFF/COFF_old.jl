__precompile__()
module COFF

# This package implements the ObjFileBase interface
import ObjFileBase
import ObjFileBase: sectionsize, sectionoffset, readheader, debugsections, deref,
    endianness, strtab_lookup, readmeta, isrelocatable, sectionname, isundef,
    symbolvalue, handle, symname, symbolnum, intptr, deref

# Reexports from ObjFileBase
export sectionsize, sectionoffset, readheader, debugsections

using StructIO

import Base: show, ==, *

export Relocations

include("constants.jl")

########## COFF.jl - An implementation of the PE/COFF File format ###############

#
# Represents the actual PE/COFF file
#
abstract COFFObjectHandle <: ObjFileBase.ObjectHandle
type COFFHandle{T<:IO} <: COFFObjectHandle
    # The IO object. This field is speciallized on to avoid dispatch performance
    # hits, especially when operating on an IOBuffer, which is an important
    # usecase for in-memory files
    io::T
    # position(io) of the start of the file in the io stream.
    start::Int
    # position(io) of the COFF header. header == start iff the file is a COFF object
    # file (as opposed to a PE image file)
    header::Int
    # A uniqued strtab will be filled in on demand
    strtab
    COFFHandle(io,start,header) = new(io,start,header)
end
ObjFileBase.handle(h::COFFHandle) = h
COFFHandle{T<:IO}(io::T,start,header) = COFFHandle{T}(io,start,header)
__init__() = push!(ObjFileBase.ObjHandles, COFFHandle)

endianness(x::COFFHandle) = :NativeEndian

show(io::IO, x::COFFHandle) = print(io, "COFF Object Handle")

import Base: read, readuntil, readbytes, write, seek, seekstart, position, eof

eof(handle::COFFHandle) = eof(handle.io)
seek{T<:IO}(io::COFFHandle{T},pos::Integer) = seek(io.io,io.start+pos)
seekstart(io::COFFHandle) = seek(io.io,io.start)
position{T<:IO}(io::COFFHandle{T}) = position(io.io)-io.start

import StructIO: pack, unpack

unpack{T,ioT<:IO}(h::COFFHandle{ioT},::Type{T}) = unpack(h.io,T,:NativeEndian)
pack{T,ioT<:IO}(h::COFFHandle{ioT},::Type{T}) = pack(h.io,T,:NativeEndian)

#
# COFF Header
#
@struct immutable COFFHeader
    Machine::UInt16
    NumberOfSections::UInt16
    TimeDateStamp::UInt32
    PointerToSymbolTable::UInt32
    NumberOfSymbols::UInt32
    SizeOfOptionalHeader::UInt16
    Characteristics::UInt16
end

function printfield(io::IO,string,fieldlength)
    print(io," "^max(fieldlength-length(string),0))
    print(io,string)
end
printentry(io::IO,header,values...) = (printfield(io,header,21);println(io," ",values...))

isrelocatable(h::COFFHeader) = (h.Characteristics & (IMAGE_FILE_DLL | IMAGE_FILE_EXECUTABLE_IMAGE)) == 0
isrelocatable(h::COFFHandle) = isrelocatable(readheader(h))

using Base.Dates

function show(io::IO,h::COFFHeader)
    printentry(io,"Machine",IMAGE_FILE_MACHINE[h.Machine])
    printentry(io,"NumberOfSections", h.NumberOfSections)
    printentry(io,"TimeDateStamp", Dates.DateTime(1970,1,1,0,0,0,0) + Dates.Second(h.TimeDateStamp))
    printentry(io,"PointerToSymbolTable", "0x",hex(h.PointerToSymbolTable))
    printentry(io,"NumberOfSymbols", h.NumberOfSymbols)
    printentry(io,"SizeOfOptionalHeader", h.SizeOfOptionalHeader)
    Characteristics = String[]
    for (k,v) in IMAGE_FILE_CHARACTERISTICS
        ((k&h.Characteristics) != 0) && push!(Characteristics, v)
    end
    printentry(io,"Characteristics",join(Characteristics,", "))
end

#
# Optional Header
#
@struct immutable OptionalHeaderStandard
    Magic::UInt16
    MajorLinkerVersion::UInt8
    MinorLinkerVersion::UInt8
    SizeOfCode::UInt32
    SizeOfInitializedData::UInt32
    SizeOfUninitializedData::UInt32
    AddressOfEntryPoint::UInt32
    BaseOfCode::UInt32
end

@struct immutable IMAGE_DATA_DIRECTORY
    VirtualAddress::UInt32
    Size::UInt32
end

@struct immutable DataDirectories
    ExportTable::IMAGE_DATA_DIRECTORY
    ImportTable::IMAGE_DATA_DIRECTORY
    ResourceTable::IMAGE_DATA_DIRECTORY
    ExceptionTable::IMAGE_DATA_DIRECTORY
    CertificateTable::IMAGE_DATA_DIRECTORY
    BaseRelocatioNTable::IMAGE_DATA_DIRECTORY
    Debug::IMAGE_DATA_DIRECTORY
    Architecture::IMAGE_DATA_DIRECTORY
    GlobalPtr::IMAGE_DATA_DIRECTORY
    TLSTable::IMAGE_DATA_DIRECTORY
    LoadConfigTable::IMAGE_DATA_DIRECTORY
    BoundImport::IMAGE_DATA_DIRECTORY
    IAT::IMAGE_DATA_DIRECTORY
    DelayImportDescriptor::IMAGE_DATA_DIRECTORY
    CLRRuntimeHeader::IMAGE_DATA_DIRECTORY
    Reserverd::IMAGE_DATA_DIRECTORY
end

module PE32
    using StructIO
    import ..OptionalHeaderStandard, ..DataDirectories

    @struct immutable OptionalHeaderWindows
        ImageBase::UInt32
        SectionAlignment::UInt32
        FileAlignment::UInt32
        MajorOperatingSystemVersion::UInt16
        MinorOperatingSystemVersion::UInt16
        MajorImageVersion::UInt16
        MinorImageVersion::UInt16
        MajorSubsystemVersion::UInt16
        MinorSubsystemVersion::UInt16
        Win32VersionValue::UInt32
        SizeOfImage::UInt32
        SizeOfHeaders::UInt32
        CheckSum::UInt32
        Subsystem::UInt16
        DllCharacteristics::UInt16
        SizeOfStackReserve::UInt32
        SizeOfStackCommit::UInt32
        SizeOfHeapReserve::UInt32
        SizeOfHeapCommit::UInt32
        LoaderFlag::UInt32
        NumberOfRvaAndSizes::UInt32
    end


    @struct immutable OptionalHeader
        standard::OptionalHeaderStandard
        BaseOfData::UInt32
        windows::OptionalHeaderWindows
        directories::DataDirectories
    end

end


module PE32Plus
    using StructIO
    import ..OptionalHeaderStandard, ..DataDirectories

    @struct immutable OptionalHeaderWindows
        ImageBase::UInt64
        SectionAlignment::UInt32
        FileAlignment::UInt32
        MajorOperatingSystemVersion::UInt16
        MinorOperatingSystemVersion::UInt16
        MajorImageVersion::UInt16
        MinorImageVersion::UInt16
        MajorSubsystemVersion::UInt16
        MinorSubsystemVersion::UInt16
        Win32VersionValue::UInt32
        SizeOfImage::UInt32
        SizeOfHeaders::UInt32
        CheckSum::UInt32
        Subsystem::UInt16
        DllCharacteristics::UInt16
        SizeOfStackReserve::UInt64
        SizeOfStackCommit::UInt64
        SizeOfHeapReserve::UInt64
        SizeOfHeapCommit::UInt64
        LoaderFlag::UInt32
        NumberOfRvaAndSizes::UInt32
    end

    @struct immutable OptionalHeader
        standard::OptionalHeaderStandard
        windows::OptionalHeaderWindows
        directories::DataDirectories
    end
end

# Section Table

@struct immutable tiny_fixed_string
    str::UInt64
end

import Base: bytestring, show, print

@struct immutable SectionHeader <: Section{COFFHandle}
    Name::fixed_string{UInt64}
    VirtualSize::UInt32
    VirtualAddress::UInt32
    SizeOfRawData::UInt32
    PointerToRawData::UInt32
    PointerToRelocations::UInt32
    PointerToLinenumbers::UInt32
    NumberOfRelocations::UInt16
    NumberOfLinenumbers::UInt16
    Characteristics::UInt32
end

function sectionname(header::SectionHeader; strtab = nothing, errstrtab=true)
    name = bytestring(header.Name)
    if name[1] == '/'
        if strtab != nothing
            return strtab_lookup(strtab,parse(Int, name[2:end]))
        elseif errstrtab
            error("Section name refers to the strtab, but no strtab given")
        end
    end
    return name
end


function show(io::IO, header::SectionHeader; strtab = nothing)
    name = bytestring(header.Name)
    name2 = sectionname(header; strtab = strtab, errstrtab=false)
    printentry(io,"Name",name,name!=name2?" => "*name2:"")
    printentry(io,"VirtualSize", "0x", hex(header.VirtualSize))
    printentry(io,"VirtualAddress", "0x", hex(header.VirtualAddress))
    printentry(io,"SizeOfRawData", "0x", hex(header.SizeOfRawData))
    printentry(io,"PointerToRawData", "0x", hex(header.PointerToRawData))
    printentry(io,"PointerToRelocations", "0x", hex(header.PointerToRelocations))
    printentry(io,"PointerToLinenumbers", "0x", hex(header.PointerToLinenumbers))
    printentry(io,"NumberOfRelocations", "0x", hex(header.NumberOfRelocations))
    printentry(io,"NumberOfLinenumbers", "0x", hex(header.NumberOfLinenumbers))
    Characteristics = String[]
    for (k,v) in IMAGE_SCN_CHARACTERISTICS
        if k & IMAGE_SCN_ALIGN_MASK != 0
            continue
        end
        ((k&header.Characteristics) != 0) && push!(Characteristics, v)
    end
    if header.Characteristics & IMAGE_SCN_ALIGN_MASK != 0
        push!(Characteristics,
            IMAGE_SCN_CHARACTERISTICS[header.Characteristics & IMAGE_SCN_ALIGN_MASK])
    end
    printentry(io,"Characteristics",join(Characteristics,", "))
end

@struct immutable SymbolName
    name::UInt64
end

function show(io::IO, sname::SymbolName; strtab = nothing, showredirect=true)
    if sname.name & typemax(UInt32) == 0
        if strtab !== nothing
            if showredirect
                print(io, sname.name >> 32, " => ")
            end
            print(io,strtab_lookup(strtab,sname.name>>32))
        else
            print(io, "/", sname.name >> 32)
        end
    else
        print(io,bytestring(tiny_fixed_string(sname.name)))
    end
end

function symname(sname::SymbolName;  kwargs...)
    buf = IOBuffer()
    show(buf,sname; kwargs..., showredirect=false)
    takebuf_string(buf)
end

@struct immutable SymtabEntry <: ObjFileBase.SymtabEntry{COFFHandle}
    Name::SymbolName
    Value::UInt32
    SectionNumber::UInt16
    Type::UInt16
    StorageClass::UInt8
    NumberOfAuxSymbols::UInt8
end align_packed

const IMAGE_SYM_UNDEFINED = 0
function isundef(entry::SymtabEntry)
    entry.StorageClass in (
        IMAGE_SYM_CLASS_EXTERNAL_DEF,
        IMAGE_SYM_CLASS_UNDEFINED_LABEL,
        IMAGE_SYM_CLASS_UNDEFINED_STATIC) ||
    (entry.StorageClass == IMAGE_SYM_CLASS_EXTERNAL &&
        entry.SectionNumber == IMAGE_SYM_UNDEFINED)
end
isfunction(entry::SymtabEntry) = entry.Type == 0x20

symname(sname::SymtabEntry; kwargs...) = symname(sname.Name; kwargs...)

function show(io::IO, entry::SymtabEntry; strtab = nothing)
    print(io, "0x", hex(entry.Value, 8), " ")
    if entry.SectionNumber == 0
        printfield(io, "*UND*", 5)
    elseif entry.SectionNumber == (-1%UInt16)
        printfield(io, "*ABS*", 5)
    elseif entry.SectionNumber == (-2%UInt16)
        printfield(io, "*DBG*", 5)
    else
        printfield(io, dec(entry.SectionNumber), 5)
    end
    print(io, " ",hex(entry.Type, 4)," ")
    #print(io, IMAGE_SYM_CLASS[entry.StorageClass]," ")
    show(io, entry.Name; strtab = strtab)
end

@struct immutable RelocationEntry
    VirtualAddress::UInt32
    SymbolTableIndex::UInt32
    Type::UInt16
end align_packed

function show(io::IO, entry::RelocationEntry; machine=IMAGE_FILE_MACHINE_UNKNOWN, syms = northing, strtab=nothing)
    print(io, "0x", hex(entry.VirtualAddress,8), " ")
    if machine == IMAGE_FILE_MACHINE_UNKNOWN
        print(io,hex(entry.Type,4)," ")
    else
        printfield(io,MachineRelocationMap[machine][entry.Type],maximum(map(length,MachineRelocationMap[machine])))
    end
    printfield(io,"@"*string(dec(entry.SymbolTableIndex)),6)
    if syms !== nothing
        print(io," -> ",symname(syms[entry.SymbolTableIndex+1]; strtab = strtab))
    end
end

# # # Higer level interface

import Base: length, getindex, start, done, next

# # Sections
immutable Sections <: ObjFileBase.Sections{COFFHandle}
    h::COFFHandle
    num::UInt16
    offset::Int
    Sections(h::COFFHandle, num::UInt16, offset::Int) = new(h,num,offset)
    function Sections(handle::COFFHandle,header::COFFHeader=readheader(handle))
        Sections(handle, header.NumberOfSections, handle.header + sizeof(COFFHeader) + header.SizeOfOptionalHeader)
    end
end
ObjFileBase.handle(s::Sections) = s.h
ObjFileBase.Sections(h::COFFHandle) = Sections(h)
ObjFileBase.mangle_sname(h::COFFHandle, name) = string(".", name)

immutable SectionRef <: ObjFileBase.SectionRef{COFFHandle}
    handle::COFFHandle
    no::Int
    offset::Int
    header::SectionHeader
end
@Base.pure ObjFileBase.SectionRef{T<:COFFHandle}(::Type{T}) = SectionRef

ObjFileBase.handle(s::SectionRef) = s.handle
sectionname(ref::SectionRef) = sectionname(ref.header; strtab=strtab(ref.handle))
deref(ref::SectionRef) = ref.header

function show(io::IO,x::SectionRef)
println(io,"0x",hex(x.offset,8),": Section #",x.no)
show(io, x.header; strtab=strtab(x.handle))
end

length(s::Sections) = s.num
const SectionHeaderSize = sizeof(SectionHeader)
function getindex(s::Sections,n)
    if n < 1 || n > length(s)
        throw(BoundsError())
    end
    offset = s.offset + (n-1)*SectionHeaderSize
    seek(s.h,offset)
    SectionRef(s.h,n,offset,unpack(s.h, SectionHeader))
end

start(s::Sections) = 1
done(s::Sections,n) = n > length(s)
next(s::Sections,n) = (s[n],n+1)

# # Symbols
immutable Symbols  <: ObjFileBase.Symbols{COFFHandle}
    h::COFFHandle
    num::UInt32
    offset::Int
    Symbols(h::COFFHandle, num, offset) = new(h,num,offset)
    function Symbols(handle::COFFHandle,header::COFFHeader=readheader(handle))
        Symbols(handle, header.NumberOfSymbols, header.PointerToSymbolTable)
    end
end
ObjFileBase.Symbols(h::COFFHandle) = Symbols(h)
ObjFileBase.handle(s::Symbols) = s.h

# Special case until Base is fixed
function Base.findnext(testf::Function, A::Symbols, start::Integer)
    while !done(A, start)
        i = start
        val, start = next(A, i)
        if testf(val)
            return i
        end
    end
    return 0
end

immutable SymbolRef <: ObjFileBase.SymbolRef{COFFHandle}
    handle::COFFHandle
    num::UInt32
    offset::Int
    entry::SymtabEntry
end
symbolnum(ref::SymbolRef) = ref.num
deref(ref::SymbolRef) = ref.entry
symname(sym::SymbolRef; strtab=COFF.strtab(sym.handle), kwargs...) = symname(sym.entry; strtab=strtab, kwargs...)
isfunction(entry::SymbolRef) = isfunction(deref(entry))
Base.seekstart(entry::SymbolRef) = seek(entry.handle,
    sectionoffset(Sections(entry.handle)[entry.entry.SectionNumber])+entry.entry.Value)

function symbolvalue(entry::Union{SymtabEntry, SymbolRef}, sects)
    entry = deref(entry)
    Value = entry.Value
    if entry.SectionNumber != 0 && entry.SectionNumber != (-1%UInt16) &&
            entry.SectionNumber != (-2%UInt16)
        sec = sects[entry.SectionNumber] 
        Value += deref(sec).VirtualAddress
    end
    Value
end

function show(io::IO,x::SymbolRef)
    print(io,'[')
    printfield(io,dec(x.num),5)
    print(io,"] ")
    show(io,x.entry; strtab=strtab(x.handle))
end

length(s::Symbols) = endof(s) # This is incorrect, but required due to quirks in Base
endof(s::Symbols) = s.num
const SymtabEntrySize = sizeof(SymtabEntry)
function getindex(s::Symbols,n)
    if n < 1 || n > endof(s)
        throw(BoundsError())
    end
    offset = s.offset + (n-1)*SymtabEntrySize
    seek(s.h,offset)
    SymbolRef(s.h,n,offset,unpack(s.h, SymtabEntry))
end

start(s::Symbols) = 1
done(s::Symbols,n) = n > endof(s)
next(s::Symbols,n) = (x=s[n];(x,n+x.entry.NumberOfAuxSymbols+1))
Base.iteratorsize(::Type{Symbols}) = Base.SizeUnknown()

# String table

immutable StrTab
    h::COFFHandle
    size::Int
    offset::Int
end

function StrTab(h::COFFHandle, header=readheader(h))
    offset = header.PointerToSymbolTable+header.NumberOfSymbols*SymtabEntrySize
    seek(h, offset)
    return StrTab(h,read(h,UInt32),offset)
end

function strtab(h::COFFHandle)
    if isdefined(h, :strtab)
        return h.strtab
    end
    h.strtab = StrTab(h)
end
ObjFileBase.StrTab(h::COFFHandle) = strtab(h)
ObjFileBase.StrTab(h::Symbols) = ObjFileBase.StrTab(handle(h))

function strtab_lookup(strtab::StrTab, offset)
    seek(strtab.h,offset+strtab.offset)
    # Strip trailing \0
    readuntil(strtab.h,'\0')[1:end-1]
end
#

const PEMAGIC = reinterpret(UInt32,UInt8['P','E','\0','\0'])[1]
const MZ = reinterpret(UInt16,UInt8['M','Z'])[1]
function readmeta(io::IO, ::Type{COFFHandle})
    start = position(io)
    if read(io,UInt16) == MZ
        # Get the PE Header offset
        seek(io, start+0x3c)
        off = read(io, UInt32)
        # PE File
        seek(io, start+off)
        read(io, UInt32) == PEMAGIC || throw(ObjFileBase.MagicMismatch("Invalid PE magic"))
    else
        seek(io,start)
        read(io, UInt32) == PEMAGIC || throw(ObjFileBase.MagicMismatch("Invalid PE magic"))
        seek(io, start)
    end
    COFFHandle(io,start,position(io))
end

readheader(h::COFFHandle) = (seek(h.io,h.header); unpack(h, COFFHeader))
function readoptheader(h::COFFHandle)
    seek(h.io,h.header + sizeof(COFFHeader))
    standard = unpack(h, OptionalHeaderStandard)
    if standard.Magic == 0x10b # PE32
        BaseOfData = read(h, UInt32)
        windows = unpack(h, PE32.OptionalHeaderWindows)
        dirs = unpack(h, DataDirectories)
        return PE32.OptionalHeader(standard, BaseOfData, windows, dirs)
    elseif standard.Magic == 0x20b # PE32Plus
        windows = unpack(h, PE32Plus.OptionalHeaderWindows)
        dirs = unpack(h, DataDirectories)
        return PE32Plus.OptionalHeader(standard, windows, dirs)
    else
        error("Unknown magic")
    end
end

function intptr(h::COFFHandle)
    header = readheader(h)
    header.Machine == IMAGE_FILE_MACHINE_AMD64 ? UInt64 :
        header.Machine == IMAGE_FILE_MACHINE_I386 ? UInt32 :
            error("Unknown Machine Type")
end

### Relocation support

immutable Relocations
    h::COFFHandle
    machine::Int
    sect::SectionHeader
end

immutable RelocationRef
    h::COFFHandle
    machine::Int
    reloc::RelocationEntry
end

show(io::IO, x::RelocationRef) = show(io,x.reloc; machine=x.machine, syms=Symbols(x.h), strtab=strtab(x.h))

Relocations(s::SectionRef) = Relocations(s.handle,readheader(s.handle).Machine,s.header)

length(s::Relocations) = s.sect.NumberOfRelocations
const RelocationEntrySize = sizeof(RelocationEntry)
function getindex(s::Relocations,n)
    if n < 1 || n > length(s)
        throw(BoundsError())
    end
    offset = s.sect.PointerToRelocations + (n-1)*RelocationEntrySize
    seek(s.h,offset)
    RelocationRef(s.h,s.machine,unpack(s.h, RelocationEntry))
end

start(s::Relocations) = 1
done(s::Relocations,n) = n > length(s)
next(s::Relocations,n) = (x=s[n];(x,n+1))

printtargetsymbol(io::IO,reloc::RelocationEntry, syms, strtab) = print(io,symname(syms[reloc.SymbolTableIndex+1]; strtab = strtab, showredirect = false))

function printRelocationInterpretation(io::IO, reloc::RelocationEntry, LocalValue::UInt64, machine, syms, sects, strtab)
    if machine == IMAGE_FILE_MACHINE_AMD64
        if reloc.Type == IMAGE_REL_AMD64_ABSOLUTE
            print(io,"0x",hex(LocalValue))
        elseif reloc.Type == IMAGE_REL_AMD64_ADDR64
            print(io,"(uint64_t) ")
            printtargetsymbol(io, reloc, syms, strtab)
            print(io," + 0x",hex(LocalValue,16))
        elseif reloc.Type == IMAGE_REL_AMD64_ADDR32
            print(io,"(uint32_t) ")
            printtargetsymbol(io, reloc, syms, strtab)
            print(io," + 0x",hex(LocalValue,8))
        elseif reloc.Type == IMAGE_REL_AMD64_ADDR32NB
            print(io,"(uint32_t) ")
            printtargetsymbol(io, reloc, syms, strtab)
            print(io," + 0x",hex(LocalValue,8))
            print(io," - ImageBase")
        elseif reloc.Type >= IMAGE_REL_AMD64_REL32 && reloc.Type <= IMAGE_REL_AMD64_REL32_5
            print(io,"(uint32_t) @pc-")
            printtargetsymbol(io, reloc, syms, strtab)
            print(io," + 0x",hex(LocalValue,8))
            add = reloc.Type-IMAGE_REL_AMD64_REL32
            print(io," + ",add)
        elseif reloc.Type == IMAGE_REL_AMD64_SECTION
            print(io,"(uint16_t) indexof(")
            printtargetsymbol(io, reloc, syms, strtab)
            print(io,")")
            LocalValue != 0 && print(io,"+",dec(LocalValue))
        elseif reloc.Type == IMAGE_REL_AMD64_SECREL
            print(io,"(uint32_t) ")
            printtargetsymbol(io, reloc, syms, strtab)
            print(io," - ")
            # Get the symbol's section
            sect = sects[syms[reloc.SymbolTableIndex].entry.SectionNumber]
            print(io,sectionname(sect))
        else
            error("Unsupported Relocations")
        end
    else
        error("Relocation Support not implemented for this Machine Type")
    end
end

function relocationLength(reloc::RelocationEntry)
    reloc.Type == IMAGE_REL_AMD64_ABSOLUTE ? 0 :
    reloc.Type == IMAGE_REL_AMD64_ADDR64 ? 8 :
    reloc.Type >= IMAGE_REL_AMD64_ADDR32 &&
    reloc.Type <= IMAGE_REL_AMD64_REL32_5 ? 4 :
    reloc.Type == IMAGE_REL_AMD64_SECTION ? 2 :
    reloc.Type == IMAGE_REL_AMD64_SECREL ? 4 :
    reloc.Type == IMAGE_REL_AMD64_SECREL7 ? 1 :
    error("Unknown relocation type")
end

function inspectRelocations(sect::SectionRef, relocs = Relocations(sect))
    data = readbytes(sect);
    handle = sect.handle
    header = readheader(handle)
    for x in relocs
      offset = x.reloc.VirtualAddress - sect.header.VirtualAddress
      size = COFF.relocationLength(x.reloc)
      # zext
      # + 1 for 1-indexed array
      Ld = data[offset+1:offset+size]
      Local = reinterpret(UInt64,vcat(Ld,zeros(UInt8,sizeof(UInt64)-size)))[1]
      print("*(",sectionname(sect),"+0x",hex(offset,8),") = ")
      COFF.printRelocationInterpretation(STDOUT, x.reloc, Local, header.Machine, Symbols(handle), Sections(handle), COFF.strtab(handle))
      println()
    end
end

import Base: readbytes

readbytes{T<:IO}(io::COFFHandle{T},sec::SectionHeader) = (seek(io,sec.PointerToRawData); readbytes(io, sec.SizeOfRawData))
readbytes(sec::SectionRef) = readbytes(sec.handle,sec.header)

function sectionsize(sec::SectionHeader)
    return sec.VirtualSize == 0 ?
        sec.SizeOfRawData : min(sec.SizeOfRawData, sec.VirtualSize)
end
sectionoffset(sec::SectionHeader) = sec.PointerToRawData

### .idata parsing
@struct immutable ImportDirectoryEntry
    ImportLookupTableRVA::UInt32
    Timestamp::UInt32
    ForwarderChain::UInt32
    NameRVA::UInt32
    ImportAddressTableRVA::UInt32
end

immutable ImportDirectoryEntries
    idata::SectionRef
end
# Does no bounds checking
function Base.getindex(entries::ImportDirectoryEntries, i)
    seek(entries.idata, (i-1)*sizeof(ImportDirectoryEntry))
    unpack(entries.idata.handle, ImportDirectoryEntry)
end
Base.start(it::ImportDirectoryEntries) = 1
Base.next(it::ImportDirectoryEntries,i) = (it[i], i+1)
function Base.done(it::ImportDirectoryEntries,i)
    x = it[i]
    x.ImportLookupTableRVA == 0 && x.Timestamp == 0 && x.ForwarderChain == 0 &&
        x.ImportAddressTableRVA == 0
end
Base.iteratorsize(it::ImportDirectoryEntries) = Base.SizeUnknown()

### DWARF support

using DWARF

function debugsections{T<:IO}(h::COFFHandle{T})
    sects = collect(Sections(h))
    snames = map(sectionname,sects)
    sections = Dict{String,SectionRef}()
    for i in 1:length(snames)
        # remove leading "."
        ind = findfirst(DWARF.DEBUG_SECTIONS,String(snames[i])[2:end])
        if ind != 0
            sections[DWARF.DEBUG_SECTIONS[ind]] = sects[i]
        end
    end
    ObjFileBase.DebugSections(h,sections)
end

include("mingw.jl")

end # module
