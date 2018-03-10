module ELF

using StructIO

# Bring in ObjectFile definitions
using ObjectFile
importall ObjectFile
using Compat

# Load in imported C #define constants
include("constants.jl")

# Start to bring in concrete types, in the order they're needed
include("ELFInternal.jl")
include("ELFHeader.jl")
include("ELFHandle.jl")
include("ELFSection.jl")
include("ELFStrTab.jl")
include("ELFSegment.jl")
include("ELFSymbol.jl")
include("ELFDynEntry.jl")
include("ELFDynamicLink.jl")

# Holdovers from ObjFileBase that I haven't cleaned up yet
#include("ELFRelocation.jl")
#include("ELFDebug.jl")

end # module ELF