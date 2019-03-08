export MachOLoadDylibCmd, MachOIdDylibCmd

export dylib_name, dylib_timestamp, dylib_version, dylib_compatibility

"""
    MachODylibStub

MachO Load Commands have an annoying and nasty habit of shimming strings into
difficult-to-reach places, such as within the header itself.  Because the
strings are variable-length, it becomes difficult to go back and find the
strings after the fact; it's better to suck it into memory immediately.  This
doesn't lend itself to `StructIO`-based IO very nicely, and so we hack our way
around the problem by creating the `Stub` which contains the data which can be
read in by `StructIO` nicely, and then immediately expanding and reading in the
`LCStr` afterward within the "true" `MachOLoadDylibCmd`.
"""
@io struct MachODylibStub
    # Note this `offset` is technically a part of the `dylib` union, but we
    # don't bother to split it out into its own `struct`.
    name_offset::UInt32
    timestamp::UInt32
    current_version::UInt32
    compatibilty::UInt32
end

"""
    MachOLoadDylibCmd

The Load Command that gives information about a dylib that must be loaded for
this Mach-O file to link properly.  The API for this laod command is given as
follows:

### Creation:
  - MachOLoadCmd()

### Accessors:
  - dylib_name()
  - dylib_timestamp()
  - dylib_version()
  - dylib_compatibility()
"""
struct MachOLoadDylibCmd{H <: MachOHandle} <: MachOLoadCmd{H}
    stub::MachODylibStub
    name::String
end

show(io::IO, lc::MachOLoadDylibCmd) = write(io, "LoadDylibCmd: \"$(dylib_name(lc))\"")


"""
    MachOIdDylibCmd

MachO dylibs have an "identity", analogous to the SONAME of an ELF shared
library.  This Load Command tells the linker about the identity of this
particular shared library.  The API of this object is identical to that of the
`MachOLoadDylibCmd` object, as they are intrinsically identical, it is the
semantic meaning behind the data that changes, and so this object is all but a
typealias for `MachOLoadDylibCmd`.
"""
struct MachOIdDylibCmd{H <: MachOHandle} <: MachOLoadCmd{H}
    stub::MachODylibStub
    name::String
end
show(io::IO, lc::MachOIdDylibCmd) = write(io, "IdDylibCmd: \"$(dylib_name(lc))\"")

"""
    MachODylibCmd

We define some operations that work on either a `MachOLoadDylibCmd` or
`MachOIdDylibCmd` load command, and to make it all pretty and shiny we define
this union type that allows our operations to be generic.
"""
const DylibCmd = Union{MachOLoadDylibCmd, MachOIdDylibCmd}

"""
    MachOLoadCmd(oh::MachOHeader, CT::Type{MachOLoadDylibCmd}, header)
    MachOLoadCmd(oh::MachOHeader, CT::Type{MachOIdDylibCmd}, header)

Manual override to unpack a `MachOLoadDylibCmd` from a MachO file and
immediately read in the associated name string.  See `MachODylibStub` for more.
"""
function MachOLoadCmd(oh::H, CT::Type{CTT}, header) where {CTT <: DylibCmd} where {H <: MachOHandle}
    # First, unpack the stub
    stub = unpack(oh, MachODylibStub)

    # Next, read in the string, telling it to not read in more than the total
    # load command size, and not before the DylibStub object finishes.
    offset = stub.name_offset - sizeof(MachODylibStub) - sizeof(MachOLoadCmdHeader{H})
    name = unpack_lcstr(oh, offset, load_cmd_size(header))

    # Finally, return our DylibCmd
    return CT(stub, name)
end

"""
    dylib_name(cmd)

Return the name of the dylib referred to by the given Load Command.
"""
dylib_name(cmd::DylibCmd) = cmd.name

"""
    dylib_timestamp(cmd)

Return the build timestamp of the dylib referred to by the given Load Command.
"""
dylib_timestamp(cmd::DylibCmd) = cmd.stub.timestamp

"""
    dylib_version(cmd)

Return the version of the dylib referred to by the given Load Command.
"""
dylib_version(cmd::DylibCmd) = cmd.stub.current_version

"""
    dylib_compatibility(cmd)

Return the compatibility version of the dylib referred to by the given Load
Command.
"""
dylib_compatibilty(cmd::DylibCmd) = cmd.stub.compatibilty

@derefmethod dylib_name(cmd::MachOLoadCmdRef{H, T}) where {H <: MachOHandle} where {T <: DylibCmd}
@derefmethod dylib_timestamp(cmd::MachOLoadCmdRef{H, T}) where {H <: MachOHandle} where {T <: DylibCmd}
@derefmethod dylib_version(cmd::MachOLoadCmdRef{H, T}) where {H <: MachOHandle} where {T <: DylibCmd}
@derefmethod dylib_compatibilty(cmd::MachOLoadCmdRef{H, T}) where {H <: MachOHandle} where {T <: DylibCmd}


"""
    MachORPathCmd

The Load Command that holds the RPATH of this object.
"""
struct MachORPathCmd{H <: MachOHandle} <: MachOLoadCmd{H}
    rpath_offset::UInt32
    rpath::String
end

show(io::IO, lc::MachORPathCmd) = write(io, "RPathCmd: \"$(rpath(lc))\"")

"""
    MachOLoadCmd(oh::MachOHeader, CT::Type{MachORPathCmd}, header)

Manual override to unpack a `MachORPathCmd` from a MachO file and
immediately read in the associated rpath string.
"""
function MachOLoadCmd(oh::H, CT::Type{CTT}, header) where {CTT <: MachORPathCmd} where {H <: MachOHandle}
    rpath_offset = read(oh, UInt32)

    # Next, read in the string, telling it to not read in more than the total
    # load command size, and not before the DylibStub object finishes.
    offset = rpath_offset - sizeof(UInt32) - sizeof(MachOLoadCmdHeader{H})
    name = unpack_lcstr(oh, offset, load_cmd_size(header))

    # Finally, return our RPathCmd
    return CT(rpath_offset, name)
end

rpath(cmd::MachORPathCmd) = cmd.rpath
@derefmethod rpath(cmd::MachOLoadCmdRef{H,MachORPathCmd{H}}) where {H <: MachOHandle}
