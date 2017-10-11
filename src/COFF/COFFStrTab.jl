export COFFStrTab

"""
    COFFStrTab

COFF `StrTab` type, containing the metadata necessary to perform string table
lookups, via the `strtab_lookup()` method.
"""
immutable COFFStrTab{H <: COFFHandle} <: StrTab{H}
    handle::COFFHandle
    offset::UInt32
end

StrTab(oh::H) where {H <: COFFHandle} = COFFStrTab{H}(oh, UInt32(strtab_offset(oh)))
handle(oh::COFFStrTab) = oh.handle

function strtab_lookup(strtab::COFFStrTab, index)
    seek(handle(strtab), strtab.offset + index)
    return strip(readuntil(handle(strtab), '\0'), '\0')
end

"""
    fixed_string_lookup(oh::COFFHandle, name)

Given a fixed string (or any `String`, really) check to see if it's a literal
string or an `strtab_lookup`.  If the latter, then perform the lookup
"""
function fixed_string_lookup(oh::COFFHandle, name)
    if !isempty(name) && name[1] == '/'
        # Wow, COFF files are weird.
        strtab = StrTab(oh)
        return strtab_lookup(strtab, parse(Int, name[2:end]))
    end
    return name
end

function fixed_string_lookup(oh::COFFHandle, name::fixed_string)
    return fixed_string_lookup(oh, unsafe_string(name))
end