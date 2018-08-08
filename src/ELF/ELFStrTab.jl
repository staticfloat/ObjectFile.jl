export ELFStrTab

"""
    ELFStrTab

ELF string table type, containing information about a `Section` that contains
a string table.  Note that an ELF file may contain multiple string tables, use
the different constructors to reference the different string tables.
"""
struct ELFStrTab{H <: ELFHandle} <: StrTab{H}
    section_ref::SectionRef{H}

    # Do a little bit of section checking
    function ELFStrTab{H}(section::ELFSectionRef{H}) where {H <: ELFHandle}
        # If this isn't actually a string table section, warn the user!
        if section_type(section) != SHT_STRTAB
            section_idx = section_number(section)
            msg = strip("""
            Loading Section $(section_idx) as a StrTab, despite it having section
            type $(section_type_string(section)), not SHT_STRTAB.
            """)
            @warn(replace(msg, "\n" => " "), key=(handle(section), section_idx))
        end
        
        return new(section)
    end
end

"""
    StrTab(section::SectionRef{ELFHandle})

Special short-cut constructor to build an `StrTab` directly from an ELF
`Section`, without attempting to automatically discover the correct section for
a string table.
"""
StrTab(section::ELFSectionRef{H}) where {H <: ELFHandle} = ELFStrTab{H}(section)

"""
    StrTab(oh::ELFHandle)

Given an ELF object, construct an `ELFStrTab` that refers to the section
header string table.
"""
function StrTab(oh::H) where {H <: ELFHandle}
    section_index = section_header_strtab_index(oh)
    strtab_section = Sections(oh)[section_index]
    return ELFStrTab{H}(strtab_section)
end

handle(strtab::ELFStrTab) = handle(strtab.section_ref)

"""
    section_header_strtab_index(oh::ELFHandle)

In an ELF object file, the section header string table is located within a
designated ELF `Section`, this method returns the index of that section.  This
is used by `StrTab(::ELFHandle)` to locate the correct `SectionRef` to
construct an `StrTab` object from.  The returned value is an index (e.g. it is
1-based, not zero-based as the value within the ELF object itself).
"""
function section_header_strtab_index(oh::ELFHandle)
    return header(oh).e_shstrndx + 1
end

function strtab_lookup(strtab::ELFStrTab, index)
    seek(strtab.section_ref, index)
    return strip(readuntil(handle(strtab), '\0'), '\0')
end