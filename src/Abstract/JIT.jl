# JIT Utils

"""
    is_jit_section(section::Section)

Returns `true` if the given section is detected to be a JIT'ed section, e.g. if
its `sectionaddress` is preposterously high, such as over `0x100000`.
"""
function is_jit_section(section::Section)
    return sectionaddress(section) > 0x100000
end
@derefmethod is_jit_section(s::SectionRef)

"""
    replace_sections(oh::ObjectHandle, new_buffer)

Allows the direct reading of JIT sections into a buffer
"""
function replace_sections(oh::T, new_buffer) where {T <: ObjectHandle}
    for sec in Sections(oh)
        if ObjFileBase.is_jit_section(sec)
            seek(new_buffer,sectionoffset(sec))
            write(new_buffer,pointer_to_array(
                reinterpret(Ptr{UInt8},sectionaddress(sec)),
                sectionsize(sec),false))
        end
    end
    seekstart(new_buffer)
    new_buffer
end