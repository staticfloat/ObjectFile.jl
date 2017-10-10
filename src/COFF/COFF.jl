module COFF

using StructIO
using Compat

# Bring in ObjectFile definitions
using ObjectFile
importall ObjectFile

# Load in imported C #define constants
include("constants.jl")

# Start to bring in concrete types, in the order they're needed
include("COFFHeader.jl")
include("COFFOptionalHeader.jl")
include("COFFHandle.jl")
include("COFFSection.jl")
include("COFFStrTab.jl")
include("COFFSymbol.jl")
include("COFFDynamicLink.jl")

end # module COFF