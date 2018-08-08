struct MachOStrTab{H <: MachOHandle} <: StrTab{H}
    cmd::MachOLoadCmdRef{H,MachOSymtabCmd{H}}
end

function StrTab(cmd::MachOLoadCmdRef{H,MachOSymtabCmd{H}}) where {H <: MachOHandle}
    return MachOStrTab(cmd)
end
function StrTab(oh::MachOHandle)
    cmds = findall(MachOLoadCmds(oh), [MachOSymtabCmd])
    if isempty(cmds)
        error("Mach-O file does not contain Symtab load commands")
    end
    return StrTab(first(cmds))
end

handle(strtab::MachOStrTab) = handle(strtab.cmd)
strtab_lookup(strtab::MachOStrTab, index) = strtab_lookup(strtab.cmd, index)