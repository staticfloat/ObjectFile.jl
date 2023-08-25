export MachOHandle

abstract type AbstractMachOHandle{T <: IO} <: ObjectHandle end

struct MachOHandle{T <: IO} <: AbstractMachOHandle{T}
    # Backing IO and start point within the IOStream of this MachO object
    io::T
    start::Int64

    # The parsed-out header of the MachO object
    header::MachOHeader

    # The path of the file this was created with, if it exists
    path::String
end

function readmeta(io::IO, ::Type{AbstractMachOHandle})
    start = position(io)

    # Peek at the magic
    magic = read(io,UInt32)
    seek(io, start)

    # See which magic it is:
    header_type = macho_header_type(magic)
    endianness = macho_endianness(magic)

    header_type, endianness
end

function readmeta(io::IO,::Type{MachOHandle})
    start = position(io)
    header_type, endianness = readmeta(io, AbstractMachOHandle)
    !(header_type <: MachOFatHeader) || throw(MagicMismatch("Binary is fat"))

    # Unpack the header
    header = unpack(io, header_type, endianness)
    return [MachOHandle(io, Int64(start), header, path(io))]
end

## IOStream-like operations:
startaddr(oh::AbstractMachOHandle) = oh.start
iostream(oh::AbstractMachOHandle) = oh.io


## Format-specific properties:
header(oh::AbstractMachOHandle) = oh.header
endianness(oh::AbstractMachOHandle) = macho_endianness(header(oh).magic)
Platform(oh::MachOHandle) = Platform(macho_cpu_to_arch(header(oh).cputype), "macos")
is64bit(oh::MachOHandle) = macho_is64bit(header(oh).magic)
isrelocatable(oh::MachOHandle) = header(oh).filetype == MH_OBJECT
isexecutable(oh::MachOHandle) = header(oh).filetype == MH_EXECUTE
islibrary(oh::MachOHandle) = header(oh).filetype == MH_DYLIB
isdynamic(oh::MachOHandle) = !isempty(findall(MachOLoadCmds(oh), [MachOLoadDylibCmd]))
mangle_section_names(oh::MachOHandle, name) = string("__", name)
mangle_symbol_name(oh::MachOHandle, name::AbstractString) = string("_", name)
format_string(::Type{H}) where {H <: AbstractMachOHandle} = "MachO"

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
