# Export datatypes
export ELFDynamicLinks, ELFDynamicLink, ELFRPath

# Export methods
export DynamicLinks, DynamicLink, StrTab, RPath

import Base: getindex, show

"""
    ELFDynamicLinks

ELF dynamic linkage table, contains the list dynamic loader commands, see the
`ELFDynEntry` type for an opaque and unhelpful detailing of these commands.
"""
struct ELFDynamicLinks{H <: ELFHandle} <: DynamicLinks{H}
    section_ref::SectionRef{H}
    links::Vector
end

"""
    DynamicLinks(oh::ELFHandle)

Return the `ELFDynamicLinks` object that is contained within the first
`.dynamic` section within the ELF object.
"""
function DynamicLinks(oh::ELFHandle)
    sections = Sections(oh)
    dyn_section = findfirst(sections, ".dynamic")

    # Create half-initialized `DynamicLinks` object, so we have it around to
    # pass to the `DynamicLink()` constructor below
    dls = ELFDynamicLinks(dyn_section, DynamicLink[])

    # Find all our DT_NEEDED DynEntries
    des = ELFDynEntries(oh, [DT_NEEDED])

    # Now push those onto our half-initialized DynamicLinks object, linking
    # them back to it
    for idx in 1:length(des)
        push!(dls.links, DynamicLink(dls, des[idx]))
    end

    # Return our DynamicLinks object
    return dls
end
Section(dls::ELFDynamicLinks) = dls.section_ref
handle(dls::ELFDynamicLinks) = handle(Section(dls))
lastindex(dls::ELFDynamicLinks) = lastindex(dls.links)
getindex(dls::ELFDynamicLinks, idx) = getindex(dls.links, idx)

"""
    StrTab(dls::ELFDynamicLinks)

Given an ELF `DynamicLinks` container, construct an `ELFStrTab` that refers to
the associated dynamic string table.
"""
function StrTab(dls::ELFDynamicLinks{H}) where {H <: ELFHandle}
    # The `sh_link` field in a ".dynamic" section always points to the
    # dynamic string table (usually called ".dynstr")
    section_idx = deref(Section(dls)).sh_link+1
    strtab_section = Sections(handle(dls))[section_idx]
    return ELFStrTab{H}(strtab_section)
end


struct ELFDynamicLink{H <: ELFHandle} <: DynamicLink{H}
    dls::ELFDynamicLinks{H}
    dyn_entry::ELFDynEntryRef{H}
end

function DynamicLink(dls::ELFDynamicLinks{H},
                     dyn_entry::ELFDynEntryRef{H}) where {H <: ELFHandle}
    return ELFDynamicLink(dls, dyn_entry)
end

DynamicLinks(dl::ELFDynamicLink) = dl.dls
handle(dl::ELFDynamicLink) = handle(DynamicLinks(dl))

function path(dl::ELFDynamicLink)
    strtab = StrTab(DynamicLinks(dl))
    return strtab_lookup(dl.dyn_entry)
end


"""
    ELFRPath

Stores the RPath entries from an ELF object
"""
struct ELFRPath{H <: ELFHandle} <: RPath{H}
    section_ref::SectionRef{H}
    rpath::Vector{<:AbstractString}
end

"""
    RPath(oh::ELFHandle)

Return the `ELFRPath` object that is contained within the first `.dynamic`
section within the ELF object.
"""
function RPath(oh::ELFHandle)
    sections = Sections(oh)
    dyn_section = findfirst(sections, ".dynamic")

    # Get all dyn entries that are DT_RUNPATH or DT_RPATH
    des = ELFDynEntries(oh, [DT_RPATH, DT_RUNPATH])
    
    # Lookup each and every one of those strings, split them out into paths
    colon_paths = String[strtab_lookup(d) for d in des]
    paths = AbstractString[]
    for colon_path in colon_paths
        for component in split(colon_path, ':')
            push!(paths, component)
        end
    end

    # Return our RPath object
    return ELFRPath(dyn_section, paths)
end

Section(rpath::ELFRPath) = rpath.section_ref
handle(rpath::ELFRPath) = handle(Section(rpath))
rpaths(rpath::ELFRPath) = rpath.rpath
