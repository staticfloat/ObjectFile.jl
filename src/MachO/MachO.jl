module MachO

using StructIO
using Compat

# Bring in ObjectFile definitions
using ObjectFile
importall ObjectFile

# Load in imported C #define constants
include("constants.jl")

# Start to bring in concrete types, in the order they're needed
include("MachOHeader.jl")
include("MachOHandle.jl")
include("MachOLoadCmd.jl")
include("MachOSegment.jl")
include("MachOSection.jl")
include("MachODynamicLink.jl")
include("MachOStrTab.jl")
include("MachOSymbol.jl")

# We do not yet support Fat (Universal) MachO binaries, as I have yet to come
# up with a nice abstraction over them that fits in well with COFF/ELF.
include("MachOFat.jl")


end # module MachO