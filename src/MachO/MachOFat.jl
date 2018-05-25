# Eventually, we will hopefully support multiarch MachO files
@io struct MachOFatArch
    cputype::UInt32
    cpusubtype::UInt32
    offset::UInt32
    size::UInt32
    align::UInt32
end

struct MachOFatHeader{H <: ObjectHandle} <: MachOHeader{H}
    magic::UInt32
    archs::Vector{MachOFatArch}
end

function StructIO.unpack(io::IO, T::Type{<:MachOFatHeader}, endian::Symbol)
    magic = read(io, UInt32)
    nfats = unpack(io, UInt32, endian)
    archs = Array{MachOFatArch}(nfats)
    for i = 1:nfats
        archs[i] = unpack(io, MachOFatArch, endian)
    end
    T(magic, archs)
end
