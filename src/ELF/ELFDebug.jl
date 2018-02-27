# DWARF support
#=
function read(io::IO,file::ELFFile,h::ELFSectionHeader,::Type{DWARF.ARTable})
    seek(io,h.sh_offset)
    ret = DWARF.ARTable(Array(DWARF.ARTableSet,0))
    while position(io) < h.sh_offset + h.sh_size
        push!(ret.sets,read(io,DWARF.ARTableSet,f.endianness))
    end
    ret
end

function read(io::IO,file::ELFFile,h::ELFSectionHeader,::Type{DWARF.PUBTable})
    seek(io,h.sh_offset)
    ret = DWARF.PUBTable(Array(DWARF.PUBTableSet,0))
    while position(io) < h.sh_offset + h.sh_size
        push!(ret.sets,read(io,DWARF.PUBTableSet,f.endianness))
    end
    ret
end

function read(io::IO,f::ELFFile,h::ELFSectionHeader,::Type{DWARF.AbbrevTableSet})
    seek(io,h.sh_offset)
    read(io,AbbrevTableSet,f.endianness)
end

function read(io::IO,f::ELFFile,h::ELFSectionHeader,s::DWARF.PUBTableSet,::Type{DWARF.DWARFCUHeader})
    seek(io,h.sh_offset+s.header.debug_info_offset)
    read(io,DWARF.DWARFCUHeader,f.endianness)
end

function read(io::IO,f::ELFFile,debug_info::ELFSectionHeader,debug_abbrev::ELFSectionHeader,
    s::DWARF.PUBTableSet,e::DWARF.PUBTableEntry,header::DWARF.DWARFCUHeader,::Type{DWARF.DIE})
    ats = read(io,f,debug_abbrev,header,DWARF.AbbrevTableSet)
    seek(io,debug_info.sh_offset+s.header.debug_info_offset+e.offset)
    read(io,header,ats,DWARF.DIE)
end

function read(io::IO,f::ELFFile,h::ELFSectionHeader,s::DWARF.DWARFCUHeader,::Type{DWARF.AbbrevTableSet})
    seek(io,h.sh_offset+s.debug_abbrev_offset)
    read(io,AbbrevTableSet,f.endianness)
end

function debugsections(io::IO,f::ELFFile)
    snames = names(io,f,f.sheaders)
    sections = Dict{String,ELFSectionHeader}()
    for i in 1:length(snames)
        # Remove leading "."
        ind = findfirst(DEBUG_SECTIONS,snames[i][2:end])
        if ind != 0
            sections[DEBUG_SECTIONS[ind]] = f.sheaders[ind]
        end
    end
    sections
end

function read(io::IO,f::ELFFile,debug_info::ELFSectionHeader,debug_abbrev::ELFSectionHeader,
    s::DWARF.PUBTableSet,e::DWARF.PUBTableEntry,header::DWARF.DWARFCUHeader,::Type{DWARF.DIETree})
    ats = read(io,f,debug_abbrev,header,DWARF.AbbrevTableSet)
    seek(io,debug_info.sh_offset+s.header.debug_info_offset+e.offset)
    ret = DIETree(Array(DWARF.DIETreeNode,0))
    read(io,header,ats,ret,DWARF.DIETreeNode,f.endianness)
    ret
end
=#

struct dl_phdr_info
    dlpi_addr::UInt64
    dlpi_name::Ptr{UInt8}
    dlpi_phdr::Ptr{Cvoid}
    dlpi_phnum::UInt16
end

function callback(info::Ptr{dl_phdr_info},size::Csize_t, data::Ptr{Cvoid})
    push!(unsafe_pointer_to_objref(data),unsafe_load(info))
    convert(Cint,0)
end

function loaded_libraries()
    x = Array(dl_phdr_info,0)
    ccall(:dl_iterate_phdr, Cint, (Ptr{Cvoid}, Any), cfunction(callback, Cint, (Ptr{dl_phdr_info},Csize_t,Ptr{Cvoid})), x)
    x
end

## DWARF Support
function debugsections(h::ELFHandle)
    sects = collect(Sections(h))
    strt = strtab(h)
    snames = map(s->sectionname(s.header;strtab=strt),sects)
    sections = Dict{String,SectionRef}()
    for i in 1:length(snames)
        # remove leading "."
        ind = findfirst(ObjFileBase.DEBUG_SECTIONS,string(snames[i])[2:end])
        if ind != 0
            sections[ObjFileBase.DEBUG_SECTIONS[ind]] = sects[i]
        end
    end
    ObjFileBase.DebugSections(h,sections)
end