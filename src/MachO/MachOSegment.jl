export MachOSegments, MachOSegment, MachOSegmentRef

"""
    MachOSegments

`Segments` type that contains all load commands within a Mach-O file that
contain segment commands.
"""
struct MachOSegments{H <: MachOHandle, S <: MachOLoadCmdRef} <: Segments{H}
    handle::H
    segments::Vector{S}
end

function Segments(lcs::MachOLoadCmds)
    return MachOSegments(handle(lcs), findall(lcs, [MachOSegmentCmd]))
end
function Segments(oh::MachOHandle)
    # Sub out to our MachOLoadCmds-based constructor
    return Segments(MachOLoadCmds(oh))
end

handle(segments::MachOSegments) = segments.handle
lastindex(segments::MachOSegments) = lastindex(segments.segments)
function getindex(segs::MachOSegments{H}, idx) where {H <: MachOHandle}
    seg = MachOSegment(segs.segments[idx])
    return MachOSegmentRef(segs, seg, UInt32(idx))
end


"""
    MachOSegment

MachO `Segment` type which is returned from a `MachOSegmentRef` when it is
dereferenced.  Note that this type exists only for the purposes of type
conformity; all the real work is done within `MachOSegmentCmd`; but since that
already inherits from `MachOLoadCmd`, it cannot also inherit from `Segment`.
Thus, this wrapper type was born to bridge the type hierarchy.
"""
struct MachOSegment{H <: MachOHandle, S <: MachOSegmentCmd{H}} <: Segment{H}
    seg::MachOLoadCmdRef{H,S}
end

Segment(seg::MachOLoadCmdRef{H,MachOSegmentCmd{H}}) where {H <: MachOHandle} = MachOSegment(seg)

MachOLoadCmdRef(seg::MachOSegment) = seg.seg
MachOLoadCmd(seg::MachOSegment) = deref(MachOLoadCmdRef(seg))

is64bit(seg::MachOSegment) = isa(seg.seg, MachOSegment64Cmd)
segment_name(seg::MachOSegment) = segment_name(seg.seg)
segment_offset(seg::MachOSegment) = segment_offset(seg.seg)
segment_file_size(seg::MachOSegment) = segment_file_size(seg.seg)
segment_memory_size(seg::MachOSegment) = segment_memory_size(seg.seg)
segment_num_sections(seg::MachOSegment) = segment_num_sections(seg.seg)


"""
    MachOSegmentRef

MachO `SegmentRef` type which is returned from a `MachOSegments` when it is
indexed into.  Note that this type exists only for the purposes of type
conformity; all the real work is done within `MachOSegmentCmd`; but since that
already inherits from `MachOLoadCmd`, and we needed a `MachOSegment` type that
would inherit from `Segment`, we figured might as well make a `MachOSegmentRef`
as well to keep things nice and symmetric.
"""
struct MachOSegmentRef{H <: MachOHandle} <: SegmentRef{H}
    segments::MachOSegments{H}
    segment::MachOSegment{H}
    idx::UInt32
end
function SegmentRef(segs::MachOSegments, seg::MachOSegment, idx)
    return MachOSegmentRef(segs, seg, idx)
end

Segments(seg::MachOSegmentRef) = seg.segments
segment_number(seg::MachOSegmentRef) = seg.idx
deref(seg::MachOSegmentRef) = seg.segment
@derefmethod MachOLoadCmdRef(seg::MachOSegmentRef)
@derefmethod segment_num_sections(seg::MachOSegmentRef)
@derefmethod segment_name(seg::MachOSegmentRef)
@derefmethod is64bit(seg::MachOSegmentRef) 


# Printing
function show(io::IO, seg::Union{MachOSegment,MachOSegmentRef})
    print(io, "MachO Segment", is64bit(seg) ? " (64 bit)" : "")

    if !get(io, :compact, false)
        fsz = string(segment_file_size(seg), base=16)
        msz = string(segment_memory_size(seg), base=16)

        println(io)
        println(io, "       Name: $(segment_name(seg))")
        println(io, "       Size: (File: 0x$(fsz),   Mem: 0x$(msz))")
        println(io, "     Offset: 0x$(string(segment_offset(seg), base=16))")
        print(io,   "   Sections: $(segment_num_sections(seg))")
    else
        print(io, " $(segment_name(seg))")
    end
end
