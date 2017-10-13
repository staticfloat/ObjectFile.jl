export ELFInternal

@io struct ELFInternal
    # ELF object class (32bit/64bit)
    class::UInt8

    # Data (used to check for endianness)
    data::UInt8

    # ELF version
    version::UInt8

    # OS ABI version
    osabi::UInt8

    # ELF ABI version
    abiversion::UInt8
end align_packed

"""
ELFInternal

Internal datastructure used within the ELF file format to convey fundamental
information such as the endianness of the file, whether it's a 32-bit or 64-bit
ELF file, etc...
"""
ELFInternal

# Define some helper functions on ELFInternal stuff
function elf_internal_endianness(ei::ELFInternal)
    if ei.data == ELFDATA2MSB
        :BigEndian
    elseif ei.data == ELFDATA2LSB
        :LittleEndian
    else
        error("Invalid Data Specification")
    end
end

function elf_internal_is64bit(ei::ELFInternal)
    if ei.class == ELFCLASS32
        return false
    elseif ei.class == ELFCLASS64
        return true
    else
        error("Invalid ELF Class ($(class))")
    end
end