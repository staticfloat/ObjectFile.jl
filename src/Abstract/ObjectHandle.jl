# Export ObjectHandle API
export ObjectHandle,
       readmeta,
       seek, seekstart, skip, iostream, position, read, readuntil, eof,
       endianness, is64bit, isrelocatable, isexecutable, islibrary, isdynamic,
       mangle_section_name, mangle_symbol_name, handle, header, format_string,
       section_header_offset, section_header_size, section_header_type,
       segment_header_offset, segment_header_size, segment_header_type,
       symtab_entry_offset, symtab_entry_size, symtab_entry_type,
       path, find_library, find_libraries

export MagicMismatch

# Import methods for extension
import Base: seek, seekstart, skip, position, read, readuntil, eof,
             getindex
import Base.Sys: isexecutable
import StructIO: unpack

"""
    ObjectHandle

The basic type that provides access to object files.  The list of available API
operations is given below, with methods that subclasses must implement marked
in emphasis.  Note tha "must implement" is a bit of a misnomer, if an Object
file does not have need of a certain piece of this API (e.g. `COFF` files have
no concept of `Segment`s), leaving that chunk of the API undefined will simply
cause errors if a user attempts to use methods that use that part of the API
(in the example above, an error will be thrown if the user calls `Segments(oh)`
where `oh <: COFFHandle`).

### Creation
  - *readmeta()*

### IOStream-like operations:
  - seek()
  - seekstart()
  - skip()
  - startaddr()
  - iostream()
  - position()
  - read()
  - readuntil()
  - eof()
  - unpack()

### Format-specific properties
  - *Platform()*
  - *endianness()*
  - *is64bit()*
  - *isrelocatable()*
  - *isexecutable()*
  - *islibrary()*
  - *isdynamic()*
  - *mangle_section_name()*
  - *mangle_symbol_name()*
  - handle()
  - *header()*
  - *format_string()*

### Section properties
  - *section_header_offset()*
  - *section_header_size()*
  - *section_header_type()*

### Segment properties
  - *segment_header_offset()*
  - *segment_header_size()*
  - *segment_header_type()*

### Symbol properties
  - *symtab_entry_offset()*
  - *symtab_entry_size()*
  - *symtab_entry_type()*

### Misc
  - *path()*
  - show()
  - find_library()
  - find_libraries()
"""
abstract type ObjectHandle end

"""
    MagicMismatch

This is an error type used to denote that `readmeta()` was called on a file
that does not contain the proper magic at the beginning for the type of object
file that was attempting to be loaded.
"""
struct MagicMismatch
    message
end

"""
    ObjTypes::Vector{Type}

`ObjTypes` contains the registry of file formats that will be used to try and
open a object file, (e.g. `ELF`, `MachO`, etc...).  This vector is initialized
at `__init__()` time, and used within `readmeta()`.
"""
const ObjTypes = Type[]

"""
    readmeta(io::IO, ::ObjectHandle)

Read an Object File out from an `IOStream`.  This is the first method you
should call in order to manipulate object files.
"""
function readmeta(io::IO, ::Type{T}) where {T<:ObjectHandle}
    # Implementing packages such as MachO.jl must explicitly override this
    error("$T must implement readmeta")
end

"""
    readmeta(io::IO)

Read an Object File out from an `IOStream`, guessing at the type of object
within the stream by calling `readmeta(io, T)` for each `T` within `ObjTypes`,
and returning the first that does not throw a `MagicMismatch`.
"""
function readmeta(io::IO)
    pos = position(io)
    for T in ObjTypes
        seek(io,pos)
        try
            return readmeta(io, T)
        catch e
            if !isa(e,MagicMismatch) && !isa(e,EOFError)
                rethrow(e)
            end
        end
    end

    # If the file didn't match anything, error out
    msg = strip("""
    Object file is not any of $(join(ObjTypes, ", "))!
    To force one object file format use readmeta(io, T).
    """)
    throw(MagicMismatch(replace(msg, "\n" => " ")))
end

function readmeta(file::AbstractString)
    @warn("`readmeta(file::AbstractString)` is deprecated, use the do-block variant instead.")
    return readmeta(open(file, "r"))
end

"""
    readmeta(f::Function, file::AbstractString)

Do-block variant of `readmeta()`.  Use via something like:

    readmeta("libfoo.so") do f
        ...
    end
"""
function readmeta(f::Function, file::AbstractString)
    io = open(file, "r")
    try
        return f(readmeta(io))
    finally
        close(io)
    end
end


## IOStream-like operations
"""
    iostream(oh::ObjectHandle)

Returns the `IOStream` backing the `ObjectHandle`
"""
@mustimplement iostream(oh::ObjectHandle)

"""
    startaddr(oh::ObjectHandle)

Returns the offset within the underlying `IOStream` at which this
`ObjectHandle` is located.
"""
@mustimplement startaddr(oh::ObjectHandle)

unpack(oh::ObjectHandle, T) = unpack(iostream(oh), T, endianness(oh))
position(oh::ObjectHandle) = position(iostream(oh)) - startaddr(oh)
seek(oh::ObjectHandle, pos::Integer) = seek(iostream(oh), startaddr(oh) + pos)
seekstart(oh::ObjectHandle) = seek(oh, 0)

# Generate a bunch of wrappers for ObjectHandles that just call iostream()
# intelligently, so we don't have to continually unwrap
for f in [:skip, :seekstart, :eof, :read, :readuntil, :readbytes, :write]
    @eval $(f)(oh::H, args...) where {H<:ObjectHandle} = $(f)(iostream(oh), args...)
end

"""
    Platform(oh::ObjectHandle)

Returns a `Platform` object representing the binary platform this object is built for.
"""
@mustimplement Platform(oh::ObjectHandle)

"""
    endianness(oh::ObjectHandle)

Returns the endianness of the given `ObjectHandle` (e.g. `:LittleEndian`)
"""
@mustimplement endianness(oh::ObjectHandle)

"""
    is64bit(oh::ObjectHandle)

Returns `true` if the given `ObjectHandle` represents a 64-bit object
"""
@mustimplement is64bit(oh::ObjectHandle)

"""
    isrelocatable(oh::ObjectHandle)

Returns `true` if the given `ObjectHandle` represents a relocatable object
file, e.g. an `.o` file as generated by `gcc -c`
"""
@mustimplement isrelocatable(oh::ObjectHandle)

"""
    isexecutable(oh::ObjectHandle)

Returns `true` if the given `ObjectHandle` represents an executable object
"""
@mustimplement isexecutable(oh::ObjectHandle)

"""
    islibrary(oh::ObjectHandle)

Returns `true` if the given `ObjectHandle` represents a shared library
"""
@mustimplement islibrary(oh::ObjectHandle)

"""
    isdynamic(oh::ObjectHandle)

Returns `true` if the given `ObjectHandle` makes use of dynamic linking.
"""
@mustimplement isdynamic(oh::ObjectHandle)

"""
    mangle_section_name(oh::ObjectHandle, name::AbstractString)

Turn a section `name` into the object-format specific naming convention, e.g.
returning `".bss"` for `ELF`/`COFF` files, and `"__bss"` for `MachO` files
"""
@mustimplement mangle_section_name(oh::ObjectHandle, name::AbstractString)

"""
    mangle_symbol_name(oh::ObjectHandle, name::AbstractString)

Mangle a symbol name using the object-format specific naming convention, e.g.
prefixing `"_"` for MachO files.
"""
@mustimplement mangle_symbol_name(oh::ObjectHandle, name::AbstractString)

# Silly handle() fallthrough for an ObjectHandle itself
handle(oh::ObjectHandle) = oh

"""
    header(oh::ObjectHandle)

Return the `ObjectHandle`'s header object, whatever that may be for this
particular object file format.
"""
@mustimplement header(oh::ObjectHandle)

"""
    format_string(::Type{H}) where {H <: ObjectHandle}

Return the string name of the given `ObjectHandle`, examples are "ELF",
"MachO", "COFF", etc...
"""
@mustimplement format_string(oh::Type)
format_string(::H) where {H <: ObjectHandle} = format_string(H)

"""
    section_header_offset(oh::ObjectHandle)

Given an `ObjectHandle`, return the offset (in bytes) at which the sections
start within the containing object file.
"""
@mustimplement section_header_offset(oh::ObjectHandle)

"""
    section_header_size(oh::ObjectHandle)

Given an `ObjectHandle`, return the size of a section header (used for reading
in the sections header when trying to load a `Section` object or iterating over
a `Sections` object)
"""
@mustimplement section_header_size(oh::ObjectHandle)

"""
    section_header_type(oh::ObjectHandle)

Given an `ObjectHandle`, return the type of a section header (used for reading
in the sections header when trying to load a `Section` object or iterating over
a `Sections` object).  For instance, for a 64-bit ELF file, this would return
the type `ELFSection64`
"""
@mustimplement section_header_type(oh::ObjectHandle)


"""
    segment_header_offset(oh::ObjectHandle)

Given an `ObjectHandle`, return the offset (in bytes) at which the segments
start within the containing object file.
"""
@mustimplement segment_header_offset(oh::ObjectHandle)

"""
    segment_header_size(oh::ObjectHandle)

Given an `ObjectHandle`, return the size of a segment header (used for reading
in the segments header when trying to load a `Segment` object or iterating over
a `Segments` object)
"""
@mustimplement segment_header_size(oh::ObjectHandle)

"""
    segment_header_type(oh::ObjectHandle)

Given an `ObjectHandle`, return the type of a segment header (used for reading
in the segments header when trying to load a `Segment` object or iterating over
a `Segments` object).  For instance, for a 64-bit ELF file, this would return
the type `ELFSegment64`
"""
@mustimplement segment_header_type(oh::ObjectHandle)


"""
    symtab_entry_offset(oh::ObjectHandle)

Given an `ObjectHandle`, return the offset (in bytes) at which the symbol
table starts within the containing object file.
"""
@mustimplement symtab_entry_offset(oh::ObjectHandle)

"""
    symtab_entry_size(oh::ObjectHandle)

Given an `ObjectHandle`, return the size of a symbol table entry (used for
reading in the symbol table when trying to load a `SymtabEntry` object or
iterating over a `Symbols` object).
"""
@mustimplement symtab_entry_size(oh::ObjectHandle)

"""
    symtab_entry_type(oh::ObjectHandle)

Given an `ObjectHandle`, return the type of a symbol table entry (used for
reading in the symbol table when trying to load a `SymtabEntry` object or
iterating over a `Symbols` object).  For instance, for a 64-bit ELF file, this
would return the type `ELFSymtabEntry64`
"""
@mustimplement symtab_entry_type(oh::ObjectHandle)


# Misc. stuff
"""
    path(oh::ObjectHandle)

Return the absolute path to the given `ObjectHandle`, if it was a file loaded
from the local disk.  If it was loaded from a general `IOStream` or in some
other way such that the path is unknown or unknowable, return the empty string.
"""
@mustimplement path(oh::ObjectHandle)

"""
    path(io::IO)

Try to guess the path of an `IO` object.  If it cannot be guessed, returns the
empty string.
"""
function path(io::IO)
    if hasfield(typeof(io), :name) && startswith(io.name, "<file ") && endswith(io.name, ">")
        return abspath(io.name[7:end-1])
    end
    return ""
end

function show(io::IO, oh::H) where {H <: ObjectHandle}
    print(io, "$(format_string(H)) Handle ($(is64bit(oh) ? "64" : "32")-bit)")
end

"""
    find_library(oh::ObjectHandle, soname::String)

Return the absolute path to the given `soname`, using the linker search path
that the given `ObjectHandle` would use at runtime.  See the documentation for
`find_library(::RPath, ::String)` for more details.
"""
function find_library(oh::ObjectHandle, soname::AbstractString)
    return find_library(RPath(oh), soname)
end

"""
    find_libraries(oh::ObjectHandle)

Return a mapping from sonames to absolute paths, containing all the sonames
declared as beeing needed by the given `ObjectHandle`.  See the documentation
for `find_library(::RPath, ::String)` and `RPath` for more details.
"""
function find_libraries(oh::ObjectHandle)
    rpath = RPath(oh)
    sonames = [path(dl) for dl in DynamicLinks(oh)]

    # Remove '@rpath/' prefix if it exists
    function strip_rpath(soname)
        if startswith(soname, "@rpath/")
            return soname[8:end]
        end
       return soname
    end

    # Translate `@loader_path/` to the actual path of the binary
    function strip_loader_path(soname)
        if startswith(soname, "@loader_path/")
            return joinpath(dirname(path(oh)), soname[14:end])
        end
        return soname
    end

    # Get rid of confusing loader tokens
    sonames = strip_rpath.(sonames)
    sonames = strip_loader_path.(sonames)

    return Dict(s => find_library(oh, s) for s in sonames)
end
