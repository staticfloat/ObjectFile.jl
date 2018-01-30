module MachO

using StructIO

# Bring in ObjectFile definitions
using ObjectFile
importall ObjectFile

# Load in imported C #define constants
include("constants.jl")

# Start to bring in concrete types, in the order they're needed
include("MachOHeader.jl")
include("MachOFat.jl")
include("MachOHandle.jl")
include("MachOLoadCmd.jl")
include("MachOSegment.jl")
include("MachOSection.jl")
include("MachODynamicLink.jl")
include("MachOStrTab.jl")
include("MachOSymbol.jl")


end # module MachO
