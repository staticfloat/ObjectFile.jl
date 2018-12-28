@io struct MachOSymtabCmd{H <: MachOHandle} <: MachOLoadCmd{H}
    symoff::UInt32
    nsyms::UInt32
    stroff::UInt32
    strsize::UInt32
end

show(io::IO, lc::MachOSymtabCmd) = write(io, "SymtabCmd")

# Accessors for symbols info
symtab_symbols_offset(cmd::MachOSymtabCmd) = cmd.symoff
symtab_num_symbols(cmd::MachOSymtabCmd) = cmd.nsyms

# Accessors for strtab info
symtab_strtab_offset(cmd::MachOSymtabCmd) = cmd.stroff
symtab_strtab_length(cmd::MachOSymtabCmd) = cmd.strsize

@derefmethod symtab_symbols_offset(cmd::MachOLoadCmdRef{H,MachOSymtabCmd{H}}) where {H <: MachOHandle}
@derefmethod symtab_num_symbols(cmd::MachOLoadCmdRef{H,MachOSymtabCmd{H}}) where {H <: MachOHandle}
@derefmethod symtab_strtab_offset(cmd::MachOLoadCmdRef{H,MachOSymtabCmd{H}}) where {H <: MachOHandle}
@derefmethod symtab_strtab_length(cmd::MachOLoadCmdRef{H,MachOSymtabCmd{H}}) where {H <: MachOHandle}

function strtab_lookup(cmd::MachOLoadCmdRef{H,MachOSymtabCmd{H}}, index) where {H <: MachOHandle}
    oh = handle(cmd)
    seek(oh, symtab_strtab_offset(cmd) + index)
    return strip(readuntil(oh, '\0'), '\0')
end

# We don't actually use this yet, but it doesn't hurt to have it here
@io struct MachODySymtabCmd{H <: MachOHandle} <: MachOLoadCmd{H}
    ilocalsym::UInt32
    nlocalsym::UInt32
    iextdefsym::UInt32
    nextdefsym::UInt32
    iundefsym::UInt32
    nundefsym::UInt32
    tocoff::UInt32
    ntoc::UInt32
    modtaboff::UInt32
    nmodtab::UInt32
    extrefsymoff::UInt32
    nextrefsyms::UInt32
    indirectsymoff::UInt32
    nindirectsyms::UInt32
    extreloff::UInt32
    nextrel::UInt32
    locreloff::UInt32
    nlocrel::UInt32
end
