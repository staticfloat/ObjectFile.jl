# Eventually, we will hopefully support multiarch MachO files
@io struct MachOFatArch
    cputype::UInt32
    cpusubtype::UInt32
    offset::UInt32
    size::UInt32
    align::UInt32
end

struct MachOFatHeader{H <: ObjectHandle} <: MachOHeader{H}
    archs::Vector{MachOFatArch}
end