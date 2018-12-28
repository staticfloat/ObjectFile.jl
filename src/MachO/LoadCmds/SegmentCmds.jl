export MachOSegmentCmd, MachOSegment32Cmd, MachOSegment64Cmd

export segment_name, segment_offset, segment_file_size, segment_memory_size,
       segment_num_sections

"""
    MachOSegmentCmd

Mach-O Segment load command type, containing information about the virtual
memory layout of a chunk of the program.  This type is very MachO-specific, so
it is not comparable to other object file formats directly.  However, note that
this data structure is the gateway through which the file sections are
accessed, and while there is a convenience `Sections(::MachOHandle)` method
that will abstract all that away for you, you can also directly call
`Sections(::MachOLoadCmdRef{MachOSegmentCmd})` to get the sections belonging to
the given segment.  Note that the `Sections` call works only upon a
`MachOLoadCmdRef{MachOSegmentCmd}`, it will not work on the `MachOSegmentCmd`
itself directly.

### Creation:
  - MachOSegmentCmd()

### Format-specific properties:
  - segment_name()
  - segment_offset()
  - segment_file_size()
  - segment_memory_size()
  - segment_num_sections()
"""
abstract type MachOSegmentCmd{H <: MachOHandle} <: MachOLoadCmd{H} end 
@io struct MachOSegment32Cmd{H <: MachOHandle} <: MachOSegmentCmd{H}
    segname::fixed_string{UInt128}
    vmaddr::UInt32
    vmsize::UInt32
    fileoff::UInt32
    filesize::UInt32
    maxprot::UInt32
    initprot::UInt32
    nsects::UInt32
    flags::UInt32
end

@io struct MachOSegment64Cmd{H <: MachOHandle} <: MachOSegmentCmd{H}
    segname::fixed_string{UInt128}
    vmaddr::UInt64
    vmsize::UInt64
    fileoff::UInt64
    filesize::UInt64
    maxprot::UInt32
    initprot::UInt32
    nsects::UInt32
    flags::UInt32
end

show(io::IO, lc::MachOSegment32Cmd) = write(io, "Segment32Cmd \"$(segment_name(lc))\"")
show(io::IO, lc::MachOSegment64Cmd) = write(io, "Segment64Cmd \"$(segment_name(lc))\"")

segment_name(cmd::MachOSegmentCmd) = cmd.segname
segment_offset(cmd::MachOSegmentCmd) = cmd.fileoff
segment_file_size(cmd::MachOSegmentCmd) = cmd.filesize
segment_memory_size(cmd::MachOSegmentCmd) = cmd.vmsize
segment_num_sections(cmd::MachOSegmentCmd) = cmd.nsects

@derefmethod segment_name(cmd::MachOLoadCmdRef{H,S}) where {H <: MachOHandle} where {S <: MachOSegmentCmd}
@derefmethod segment_offset(cmd::MachOLoadCmdRef{H,S}) where {H <: MachOHandle} where {S <: MachOSegmentCmd}
@derefmethod segment_file_size(cmd::MachOLoadCmdRef{H,S}) where {H <: MachOHandle} where {S <: MachOSegmentCmd}
@derefmethod segment_memory_size(cmd::MachOLoadCmdRef{H,S}) where {H <: MachOHandle} where {S <: MachOSegmentCmd}
@derefmethod segment_num_sections(cmd::MachOLoadCmdRef{H,S}) where {H <: MachOHandle} where {S <: MachOSegmentCmd}
