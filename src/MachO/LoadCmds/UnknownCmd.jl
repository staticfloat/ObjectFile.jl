"""
    MachOUnknownCmd

This represents a Load Command that we don't know what to do with.
"""
@io struct MachOUnknownCmd{H <: MachOHandle} <: MachOLoadCmd{H}
    # Naaaahsiiing
end