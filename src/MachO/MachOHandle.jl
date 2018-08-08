export MachOHandle, FatMachOHandle

struct MachOHandle{T <: IO} <: ObjectHandle
    # Backing IO and start point within the IOStream of this MachO object
    io::T
    start::Int

    # The parsed-out header of the MachO object
    header::MachOHeader
    
    # The path of the file this was created with, if it exists
    path::String
end

function readmeta(io::IO,::Type{MachOHandle})
    start = position(io)
    
    # Peek at the magic
    magic = read(io,UInt32)
    seek(io, start)

    # See which magic it is:
    header_type = macho_header_type(magic)
    endianness = macho_endianness(magic)

    # If it's fat, just throw MagicMismatch
    if header_type <: MachOFatHeader
        throw(MagicMismatch("FAT header"))
    end

    # Unpack the header
    header = unpack(io, header_type, endianness)
    return MachOHandle(io, start, header, path(io))
end

## IOStream-like operations:
startaddr(oh::MachOHandle) = oh.start
iostream(oh::MachOHandle) = oh.io


## Format-specific properties:
header(oh::MachOHandle) = oh.header
endianness(oh::MachOHandle) = macho_endianness(header(oh).magic)
is64bit(oh::MachOHandle) = macho_is64bit(header(oh).magic)
isrelocatable(oh::MachOHandle) = header(oh).filetype == MH_OBJECT
isexecutable(oh::MachOHandle) = header(oh).filetype == MH_EXECUTE
islibrary(oh::MachOHandle) = header(oh).filetype == MH_DYLIB
isdynamic(oh::MachOHandle) = !isempty(findall(MachOLoadCmds(oh), [MachOLoadDylibCmd]))
mangle_section_names(oh::MachOHandle, name) = string("__", name)
mangle_symbol_name(oh::MachOHandle, name::AbstractString) = string("_", name)
format_string(::Type{H}) where {H <: MachOHandle} = "MachO"

# Section information
section_header_size(oh::MachOHandle) = sizeof(section_header_type(oh))
function section_header_type(oh::H) where {H <: MachOHandle}
    if is64bit(oh)
        return MachOSection64{H}
    else
        return MachOSection32{H}
    end
end

# Misc. stuff
path(oh::MachOHandle) = oh.path
