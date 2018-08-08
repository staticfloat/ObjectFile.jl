"""
    COFFSections

COFF Section header table type, containing information about the number of
sections within the COFF object, the location of the section headers, etc...
"""
struct COFFSections{H <: COFFHandle} <: Sections{COFFHandle}
    handle::H
end

Sections(oh::COFFHandle) = COFFSections(oh)

# Implement Sections API
handle(sections::COFFSections) = sections.handle
lastindex(sections::COFFSections) = num_sections(header(handle(sections)))


"""
    COFFSection

COFF Section header type, containing information about a `Section` of the COFF
file such as its name, its size, location within memory, etc...
"""
@io struct COFFSection{H <: COFFHandle} <: Section{H}
    Name::fixed_string{UInt64}
    VirtualSize::UInt32
    VirtualAddress::UInt32
    SizeOfRawData::UInt32
    PointerToRawData::UInt32
    PointerToRelocations::UInt32
    PointerToLinenumbers::UInt32
    NumberOfRelocations::UInt16
    NumberOfLinenumbers::UInt16
    Characteristics::UInt32
end

function section_name(s::COFFSection)
    name = unsafe_string(s.Name)
    if name[1] == '/'
        # Wow, COFF files are weird
        return string("strtab@", parse(Int, name[2:end]))
    end
    return name
end

section_size(s::COFFSection) = s.SizeOfRawData
section_address(s::COFFSection) = s.VirtualAddress
section_offset(s::COFFSection) = s.PointerToRawData


"""
    COFFSectionRef

COFF `SectionRef` type, containing a `COFFSection` and important metadata..
"""
struct COFFSectionRef{H <: COFFHandle} <: SectionRef{H}
    sections::COFFSections{H}
    section::COFFSection{H}
    idx::UInt32
end

function SectionRef(sections::COFFSections, s::COFFSection, idx)
    return COFFSectionRef(sections, s, UInt32(idx))
end
deref(s::COFFSectionRef) = s.section
sections(s::COFFSectionRef) = s.sections
handle(s::COFFSectionRef) = handle(sections(s))
section_number(s::COFFSectionRef) = s.idx
function section_name(s::COFFSectionRef)
    name = unsafe_string(deref(s).Name)
    if !isempty(name) && name[1] == '/'
        # Wow, COFF files are weird.
        strtab = StrTab(handle(s))
        return strtab_lookup(strtab, parse(Int, name[2:end]))
    end
    return name
end
