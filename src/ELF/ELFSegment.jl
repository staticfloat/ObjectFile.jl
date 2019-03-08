export ELFSegments, ELFSegment, ELFSegment32, ELFSegment64

"""
    ELFSegments

ELF segment header table type, containing information about the number of
segments within the ELF object, the location of the segment headers, etc...
"""
struct ELFSegments{H <: ELFHandle} <: Segments{H}
    handle::H
end
Segments(oh::ELFHandle) = ELFSegments(oh)
handle(segs::ELFSegments) = segs.handle
lastindex(segs::ELFSegments) = header(handle(segs)).e_phnum


"""
    ELFSegment

ELF Segment type, also known as a program header, containing information
about the virtual memory layout of a chunk of the program.
"""
abstract type ELFSegment{H <: ELFHandle} <: Segment{H} end

@io struct ELFSegment32{H <: ELFHandle} <: ELFSegment{H}
    p_type::UInt32
    p_offset::UInt32
    p_vaddr::UInt32
    p_paddr::UInt32
    p_filesz::UInt32
    p_memsz::UInt32
    p_flags::UInt32
    p_align::UInt32
end

@io struct ELFSegment64{H <: ELFHandle} <: ELFSegment{H}
    p_type::UInt32
    p_flags::UInt32
    p_offset::UInt64
    p_vaddr::UInt64
    p_paddr::UInt64
    p_filesz::UInt64
    p_memsz::UInt64
    p_align::UInt64
end


# Construction
function read(oh::ELFHandle, ::Type{ST}) where {ST <: ELFSegment}
    type_func = segment_header_type
    size_func = segment_header_size
    return read_struct(oh, type_func, size_func, "Segment Header")
end

function contents(oh::ELFHandle, seg::ELFSegment)
    # Allocate memory to hold this segment
    data = Array(UInt8, segment_file_size(seg))

    # Seek to where this segment starts
    seek(oh, segment_offset(seg))

    # Read and return it
    read(oh, data)
    return data
end


# Accessors
segment_type(seg::ELFSegment) = seg.p_type
segment_offset(seg::ELFSegment) = seg.p_offset
segment_file_size(seg::ELFSegment) = seg.p_filesz
segment_memory_size(seg::ELFSegment) = seg.p_memsz
segment_physical_address(seg::ELFSegment) = seg.p_paddr
segment_virtual_address(seg::ELFSegment) = seg.p_vaddr
segment_address(seg::ELFSegment) = segment_virtual_address(seg)


"""
    ELFSegmentRef

Provides a reference to a `Segment`, along with a reference to the
`ObjectHandle` this `Segment` comes from.  This should be the primary method by
which users interact with segments inside object files.  The list of available
API operations is given below.  Note that this overlaps heavily with the
`Segment` object API, this is by design as many of the methods are simply
passthroughs to the underlying `Segment` API calls for ease of use.

### Creation:
  - SegmentRef()

### Utility
  - deref()
  - handle()
  - Segments()

### IO-like operations:
  - read()
  - seekstart()
  - seek()
  - eof()


### Format-specific properties:
  - segment_type()
  - segment_offset()
  - segment_file_size()
  - segment_memory_size()
  - segment_physical_address()
  - segment_virtual_address()
  - segment_number()
"""
struct ELFSegmentRef{H<:ELFHandle} <: SegmentRef{H}
    segments::ELFSegments{H}
    segment::ELFSegment{H}
    idx::UInt32
end

function SegmentRef(segments::ELFSegments{H},
                    segment::ELFSegment{H}, idx) where {H <: ELFHandle}
    return ELFSegmentRef(segments, segment, UInt32(idx))
end
deref(seg::ELFSegmentRef) = seg.segment
Segments(seg::ELFSegmentRef) = seg.segments

segment_number(seg::ELFSegmentRef) = seg.idx
@derefmethod segment_physical_address(seg::ELFSegmentRef)
@derefmethod segment_virtual_address(seg::ELFSegmentRef)
@derefmethod segment_type(seg::ELFSegmentRef)



# Printing
"""
    segment_type_string(s::ELFSegment)

Return the given `ELFSegment`'s segment type as a string.
"""
function segment_type_string(s::ELFSegment)
    global P_TYPE

    s_type = segment_type(s)
    if haskey(P_TYPE, s_type)
        return P_TYPE[s_type]
    end
    return string("Unknown Segment Type (0x", string(s_type, base=16), ")")
end
@derefmethod segment_type_string(s::ELFSegmentRef)

function show(io::IO, seg::Union{ELFSegment,ELFSegmentRef})
    print(io, "ELFSegment")

    if !get(io, :compact, false)
        fsz = string(segment_file_size(seg), base=16)
        msz = string(segment_memory_size(seg), base=16)
        paddr = string(segment_physical_address(seg), base=16)
        vaddr = string(segment_virtual_address(seg), base=16)

        println(io)
        println(io, "       Type: $(segment_type_string(seg))")
        println(io, "       Size: (File: 0x$(fsz),   Mem: 0x$(msz))")
        println(io, "     Offset: 0x$(string(segment_offset(seg), base=16))")
        print(io,   "    Address:  (Phy: 0x$(paddr) Virt: 0x$(vaddr))")
    else
        print(io, " $(segment_type_string(seg))")
    end
end
