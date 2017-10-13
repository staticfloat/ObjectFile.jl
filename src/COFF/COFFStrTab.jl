export COFFStrTab

"""
    COFFStrTab

COFF `StrTab` type, containing the metadata necessary to perform string table
lookups, via the `strtab_lookup()` method.
"""
struct COFFStrTab{H <: COFFHandle} <: StrTab{H}
    handle::COFFHandle
    offset::UInt32
end

StrTab(oh::H) where {H <: COFFHandle} = COFFStrTab{H}(oh, UInt32(strtab_offset(oh)))
handle(oh::COFFStrTab) = oh.handle

function strtab_lookup(strtab::COFFStrTab, index)
    seek(handle(strtab), strtab.offset + index)
    return strip(readuntil(handle(strtab), '\0'), '\0')
end