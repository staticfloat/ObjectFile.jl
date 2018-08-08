import Base: unsafe_string, show, print, isempty, length, *, ==, unsafe_string
export fixed_string
using StructIO

## Here we define various string-related utilities for MachO and COFF files
"""
    fixed_string{T}

A fixed-byte string, stored as an integer type (e.g. `T` = `UInt128`, or `T` =
`UInt64`) but displayed and treated as a string.
"""
@io struct fixed_string{T <: Integer}
    data::T
end


"""
    unsafe_string(x::fixed_string)

Convert a `fixed_string` object to a native-Julia `String`
"""
function unsafe_string(x::fixed_string{T}) where {T <: Integer}
    data_array = reinterpret(UInt8, [x.data])
    zero_idx = findfirst(isequal(0x00), data_array)
    if zero_idx === nothing
        zero_idx = sizeof(T) + 1
    end

    str = String(data_array[1:zero_idx-1])
    if !isvalid(str)
        return "$(zero_idx)-byte String of invalid UTF-8 data"
    end
    return str
end

## Various overrides for `fixed_string` that make it act like a `String`
show(io::IO, x::fixed_string) = show(io, unsafe_string(x))
print(io::IO, x::fixed_string) = print(io, unsafe_string(x))
isempty(x::fixed_string) = (x.data & 0xff) == 0
function length(x::fixed_string{T}) where {T <: Integer}
    for idx in 0:(sizeof(T)-1)
        if (x.data & (0xff << (idx*8))) == 0
            return idx
        end
    end
    return sizeof(T)
end

==(x::fixed_string, y::AbstractString) = unsafe_string(x) == y
==(x::AbstractString, y::fixed_string) = y==x
*(a::String, b::fixed_string) = a*unsafe_string(b)
*(a::fixed_string, b::String) = unsafe_string(a)*b



"""
    unsafe_string(io, max_len::Integer)

Read in a null-terminated string, stopping with a maximum length of `max_len`.
"""
function unsafe_string(io, max_len::T) where {T <: Integer}
    str = UInt8[]
    idx = 0
    c = read(io, UInt8)
    while c != 0x00 && idx < max_len
        push!(str, c)
        c = read(io, UInt8)
        idx += 1
    end
    return String(str)
end
