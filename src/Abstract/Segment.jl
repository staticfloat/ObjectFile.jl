# Export Segments API
export Segments, handle

# Export Segment API
export Segment, deref, segment_name, segment_offset, segment_file_size,
       segment_memory_size, segment_address

export SegmentRef, segment_number

# Import Base stuff for extension
import Base: getindex, length, eltype, findfirst, findall, iterate, keys, lastindex

"""
    Segments

An abstraction over the concept of a collection of `Segment` types within an
object file.  One can think of the `Segments` object containing the table of
segment headers within the object file, whereas the `Segment`/`SegmentRef`
objects contain the actual segment data itself.  The list of available API
operations is given below, with methods that subclasses must implement marked
in emphasis:

### Creation
  - *Segments()*

### Iteration
  - *getindex()*
  - *lastindex()*
  - length()
  - iterate()
  - keys()
  - eltype()

### Search
  - findall()
  - findfirst()

### Misc.
  - *handle()*
"""
abstract type Segments{H<:ObjectHandle} end

# Fairly simple iteration interface specification
@mustimplement lastindex(segs::Segments)
length(segs::Segments) = lastindex(segs)
keys(segs::Segments) = 1:length(segs)
iterate(segs::Segments, idx=1) = idx > length(segs) ? nothing : (segs[idx], idx+1)
eltype(::Type{S}) where {S <: Segments} = SegmentRef

function getindex(segs::Segments, idx)
    # Punt off to `getindex_ref`
    oh = handle(segs)
    return getindex_ref(
        segs,
        segment_header_offset(oh),
        segment_header_size(oh),
        segment_header_type(oh),
        SegmentRef,
        idx
    )
end




"""
    Segment

An abstraction over the concept of a `Segment` within an object file.  A
`Segment` is a portion of an object file that is given instruction on its
layout in virtual memory; this is in contrast to a `Section`, which delineates
different portions of an object file on disk.  ELF files have the strictest
separation here, with a single executable file containing multiple `Segment`
and `Section` objects, with `Section`s being assigned to one or more `Segment`s
for virtual memory placement.  Mach-O files typically have two `Segment`s, one
called `__TEXT`, one called `__DATA`.  COFF files do not have `Segment`.

Just like with `Section` objects, many operations upon segments require global
operations (access to the string table, knowledge of position within the file,
etc...) which causes some operations to be defined only upon the `SegmentRef`
datatype.  As a user, the `SegmentRef` type should be the primary method of
interacting with segments, as a developer adding new object file formats,
some methods must support `Segment`s, others must support only `SegmentRef`s.
Note that any method that works on a `Segment` must also work with a
`SegmentRef`, see the `@derefmethod` macro for a convenient helper macro to
generate `SegmentRef` -> `Section` wrapper methods. The list of available API
operations is given below, with methods that subclasses must implement marked
in emphasis:

### Creation:
  - *read()*

### Utility:
  - deref()

### Format-specific properties:
  - *segment_name()*
  - *segment_offset()*
  - *segment_file_size()*
  - *segment_memory_size()*
  - *segment_address()*
"""
abstract type Segment{H <: ObjectHandle} end

deref(seg::Segment) = seg
@mustimplement read(oh::ObjectHandle, ::Type{Segment})
@mustimplement segment_name(seg::Segment)
@mustimplement segment_offset(seg::Segment)
@mustimplement segment_file_size(seg::Segment)
@mustimplement segment_memory_size(seg::Segment)
@mustimplement segment_address(seg::Segment)



"""
    SegmentRef

Provides a reference to a `Segment`, along with a reference to the
`ObjectHandle` this `Segment` comes from.  This should be the primary method by
which users interact with segments inside object files.  The list of available
API operations is given below, with methods that subclasses must implement
marked in emphasis.  Note that this overlaps heavily with the `Segment` object
API, this is by design as many of the methods are simply passthroughs to the
underlying `Segment` API calls for ease of use.

### Creation:
  - *SegmentRef()*

### Utility
  - *deref()*
  - *Segments()*
  - handle()

### Format-specific properties:
  - *segment_name()*
  - *segment_number()*
  - segment_offset()
  - segment_file_size()
  - segment_memory_size()
  - segment_address()
"""
abstract type SegmentRef{H<:ObjectHandle} end

@mustimplement SegmentRef(segs::Segments, seg::Segment, idx)


"""
    deref(seg::SegmentRef)

Dereference the given `SegmentRef` object to a `Segment`.
"""
@mustimplement deref(seg::SegmentRef)

"""
    Segments(seg::SegmentRef)

Return the `Segments` collection this `Segment` belongs to.
"""
@mustimplement Segments(seg::SegmentRef)

"""
    handle(seg::SegmentRef)

Return the `ObjectHandle` this `SegmentRef` belongs to.  This method is
`SegmentRef`-only.
"""
handle(seg::SegmentRef) = handle(Segments(seg))


"""
    segment_name(seg::SegmentRef)

The name of the given `Segment`, returned as a string.  This method often
performs some kind of lookup within the string table of the object to get the
full name of the segment.
"""
@mustimplement segment_name(seg::SegmentRef)

"""
    segment_number(seg::SegmentRef)

Return the index of the referred segment.
"""
@mustimplement segment_number(seg::SegmentRef)

@derefmethod segment_type(seg::SegmentRef)
@derefmethod segment_offset(seg::SegmentRef)
@derefmethod segment_file_size(seg::SegmentRef)
@derefmethod segment_memory_size(seg::SegmentRef)
@derefmethod segment_address(seg::SegmentRef)



## Printing
show(io::IO, segs::Segments{H}) where {H <: ObjectHandle} = show_collection(io, segs, H)
