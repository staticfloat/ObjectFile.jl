# # # Higher level debug info support
struct DebugSections{T<:ObjectHandle, S}
    oh::T
    debug_abbrev::Nullable{S}
    debug_aranges::Nullable{S}
    debug_frame::Nullable{S}
    debug_info::Nullable{S}
    debug_line::Nullable{S}
    debug_loc::Nullable{S}
    debug_macinfo::Nullable{S}
    debug_pubnames::Nullable{S}
    debug_ranges::Nullable{S}
    debug_str::Nullable{S}
    debug_types::Nullable{S}
end
handle(dbgs::DebugSections) = dbgs.oh

function DebugSections(oh::H; debug_abbrev = nothing, debug_aranges = nothing,
        debug_frame = nothing, debug_info = nothing, debug_line = nothing,
        debug_macinfo = nothing, debug_pubnames = nothing, debug_loc= nothing,
        debug_ranges = nothing, debug_str = nothing, debug_types = nothing) where {H <: ObjectHandle}
    # Build Section typeunion
    S = Union{map(typeof, [debug_abbrev, debug_aranges, debug_frame, debug_info,
        debug_line, debug_loc, debug_macinfo, debug_pubnames, debug_ranges,
        debug_str, debug_types])...}
    DebugSections{T,S}(oh, debug_abbrev, debug_aranges, debug_frame, debug_info,
        debug_line, debug_loc, debug_macinfo, debug_pubnames, debug_ranges,
        debug_str, debug_types)
end

function DebugSections(oh::H, sections::Dict) where {H <: ObjectHandle}
    DebugSections(oh,
        debug_abbrev = get(sections, "debug_abbrev", nothing),
        debug_aranges = get(sections, "debug_aranges", nothing),
        debug_frame = get(sections, "debug_frame", nothing),
        debug_info = get(sections, "debug_info", nothing),
        debug_line = get(sections, "debug_line", nothing),
        debug_loc = get(sections, "debug_loc", nothing),
        debug_macinfo = get(sections, "debug_macinfo", nothing),
        debug_pubnames = get(sections, "debug_pubnames", nothing),
        debug_ranges = get(sections, "debug_ranges", nothing),
        debug_str = get(sections, "debug_str", nothing),
        debug_types = get(sections, "debug_types", nothing))
end

const DEBUG_SECTIONS = [
    "debug_abbrev",
    "debug_aranges",
    "debug_frame",
    "debug_info",
    "debug_line",
    "debug_loc",
    "debug_macinfo",
    "debug_pubnames",
    "debug_ranges",
    "debug_str",
    "debug_types"]

function show(io::IO, dsect::DebugSections)
    println(io, "Debug Sections for $(dsect.oh)")
    println(io, "========================= debug_abbrev =========================")
    println(io, dsect.debug_abbrev)
    println(io, "======================== debug_aranges =========================")
    println(io,  dsect.debug_aranges)
    println(io, "========================= debug_frame ==========================")
    println(io, dsect.debug_frame)
    println(io, "========================= debug_info ===========================")
    println(io, dsect.debug_info)
    println(io, "========================= debug_line ===========================")
    println(io, dsect.debug_line)
    println(io, "========================== debug_loc ===========================")
    println(io, dsect.debug_loc)
    println(io, "======================== debug_macinfo =========================")
    println(io, dsect.debug_macinfo)
    println(io, "======================= debug_pubnames =========================")
    println(io, dsect.debug_pubnames)
    println(io, "======================== debug_ranges ==========================")
    println(io, dsect.debug_ranges)
    println(io, "=========================== debug_str ==========================")
    println(io, dsect.debug_str)
    println(io, "========================= debug_types ==========================")
    println(io, dsect.debug_types)
end

"""
    debugsections(oh::ObjectHandle)

Return list of sections needed for debug info within given `ObjectHandle`
"""
@mustimplement debugsections(oh::ObjectHandle)