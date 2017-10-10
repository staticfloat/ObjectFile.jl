export COFFSymbols, COFFSymtabEntry, COFFSymbolRef

"""
    COFFSymbols

COFF symbol table, contains the list of symbols defined within the object file.
"""
immutable COFFSymbols{H<:COFFHandle} <: Symbols{H}
    handle::H
end

function Symbols(oh::H) where {H <: COFFHandle}
    return COFFSymbols(oh)
end

handle(syms::COFFSymbols) = syms.handle
endof(syms::COFFSymbols) = num_symbols(header(handle(syms)))

@io immutable COFFSymtabEntry{H <: COFFHandle} <: SymtabEntry{H}
    Name::fixed_string{UInt64}
    Value::UInt32
    SectionNumber::UInt16
    Type::UInt16
    StorageClass::UInt8
    NumberOfAuxSymbols::UInt8
end align_packed

function symbol_name(sym::COFFSymtabEntry)
    name = unsafe_string(sym.Name)
    if name[1] == '/'
        # Wow, COFF files are weird
        return string("strtab@", parse(Int, name[2:end]))
    end
    return name
end

symbol_value(sym::COFFSymtabEntry) = sym.Value
symbol_section(sym::COFFSymtabEntry) = sym.SectionNumber
symbol_type(sym::COFFSymtabEntry) = sym.Type
function isundef(sym::COFFSymtabEntry)
    sym.StorageClass in (
        IMAGE_SYM_CLASS_EXTERNAL_DEF,
        IMAGE_SYM_CLASS_UNDEFINED_LABEL,
        IMAGE_SYM_CLASS_UNDEFINED_STATIC) ||
    (sym.StorageClass == IMAGE_SYM_CLASS_EXTERNAL &&
     sym.SectionNumber == IMAGE_SYM_UNDEFINED)
end
isglobal(sym::COFFSymtabEntry) = sym.StorageClass == IMAGE_SYM_CLASS_EXTERNAL
islocal(sym::COFFSymtabEntry) = !isglobal(sym)
isweak(sym::COFFSymtabEntry) = sym.StorageClass == IMAGE_SYM_CLASS_WEAK_EXTERNAL


"""
    COFFSymbolRef

Contains a reference to an `COFFSymtabEntry`, as well as an `COFFSymbols`, etc...
"""
immutable COFFSymbolRef{H<:COFFHandle} <: SymbolRef{H}
    syms::COFFSymbols{H}
    entry::COFFSymtabEntry{H}
    idx::UInt32
end
function SymbolRef(syms::COFFSymbols, entry::COFFSymtabEntry, idx)
    return COFFSymbolRef(syms, entry, UInt32(idx))
end

deref(sym::COFFSymbolRef) = sym.entry
Symbols(sym::COFFSymbolRef) = sym.syms
symbol_number(sym::COFFSymbolRef) = sym.idx
@derefmethod symbol_type(sym::COFFSymbolRef)
symbol_name(s::COFFSymbolRef) = fixed_string_lookup(handle(s), deref(s).Name)


# Symbol printing stuff
"""
    symbol_type_string(s::COFFSymtabEntry)

Return the given `COFFSymtabEntry`'s section type as a string.
"""
function symbol_type_string(sym::COFFSymtabEntry)
    global IMAGE_SYM_TYPE

    # fast-track a zero symbol type
    if sym.Type == 0
        return ""
    end

    # We have to construct a compound type string here
    type_string = ""

    # We start with the "derived" type, e.g. pointer, array, etc...
    dtype = (sym.Type & 0xf0) >> 4
    if haskey(IMAGE_SYM_DTYPE, dtype)
        type_string = string("(", IMAGE_SYM_DTYPE[dtype], ")")
    end

    # Then, move on to the "base" type, e.g. void, char, short...
    btype = sym.Type & 0x0f
    if haskey(IMAGE_SYM_TYPE, btype)
        type_string = "$(type_string) $(IMAGE_SYM_TYPE[btype])"
    end

    # If we didn't get ANY info, complain
    if isempty(type_string)
        string("Unknown Symbol Type (0x", hex(sym.Type), ")")
    end
    
    return type_string
end
@derefmethod symbol_type_string(s::COFFSymbolRef)

function show(io::IO, sym::Union{COFFSymtabEntry,COFFSymbolRef})
    print(io, "COFFSymbol")

    if !get(io, :compact, false)
        println(io)
        println(io, "       Name: $(symbol_name(sym))")
        println(io, "      Value: $(symbol_value(sym))")
        println(io, "    Defined: $(isundef(sym) ? "No" : "Yes")")
        println(io, "     Strong: $(isweak(sym) ? "No" : "Yes")")
        print(io,   "   Locality: $(isglobal(sym) ? "Global" : "Local")")
    else
        print(io, " $(symbol_type_string(sym)) \"$(symbol_name(sym))\"")
    end
end

function show(io::IO, syms::COFFSymbols)
    print(io, "COFF Symbol Table")
    for s in syms
        print(io, "\n  ")
        showcompact(io, s)
    end
end