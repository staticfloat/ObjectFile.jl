module ObjectFile
using Reexport
import Base.BinaryPlatforms: Platform

# Include base utilities
include("utils.jl")
include("string_utils.jl")

# Include our Abstract definitions
include("Abstract/Abstract.jl")

# Include ELF format
include("ELF/ELF.jl")
@reexport using .ELF

# Include MachO format
include("MachO/MachO.jl")
@reexport using .MachO

# Include COFF format
include("COFF/COFF.jl")
@reexport using .COFF

function __init__()
    global ObjTypes

    push!(ObjTypes, ELFHandle)
    push!(ObjTypes, MachOHandle)
    push!(ObjTypes, FatMachOHandle)
    push!(ObjTypes, COFFHandle)
end

end #module ObjectFile
