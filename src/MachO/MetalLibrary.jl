@enum METALLIB_TARGET::UInt16 begin
    METALLIB_TARGET_MACOS = 0x8001
    METALLIB_TARGET_IOS = 0x0001
end

@enum METALLIB_FILETYPE::UInt8 begin
    METALLIB_FILETYPE_EXECUTABLE = 0x00
    METALLIB_FILETYPE_COREIMAGE = 0x01
    METALLIB_FILETYPE_DYNAMIC = 0x02
    METALLIB_FILETYPE_SYMBOLCOMPANION = 0x03
end

@enum METALLIB_TARGET_OS::UInt8 begin
    METALLIB_TARGET_OS_UNKNOWN = 0x00
    METALLIB_TARGET_OS_MACOS = 0x81
    METALLIB_TARGET_OS_IOS = 0x82
    METALLIB_TARGET_OS_TVOS = 0x83
    METALLIB_TARGET_OS_WATCHOS = 0x84
    METALLIB_TARGET_OS_BRIDGEOS = 0x85
    METALLIB_TARGET_OS_MACCATALYST = 0x86
    METALLIB_TARGET_OS_IOS_SIMULATOR = 0x87
    METALLIB_TARGET_OS_TVOS_SIMULATOR = 0x88
    METALLIB_TARGET_OS_WATCHOS_SIMULATOR = 0x89
end

@io struct MetallibHeader{H <: ObjectHandle} <: MachOHeader{H}
    magic::UInt32
    target::METALLIB_TARGET
    ver_major::UInt16
    ver_minor::UInt16
    filetype::METALLIB_FILETYPE
    target_os::METALLIB_TARGET_OS
    os_major::UInt16
    os_minor::UInt16
    size::UInt64
    funclist_offset::UInt64
    funclist_size::UInt64
    public_md_offset::UInt64
    public_md_size::UInt64
    private_md_offset::UInt64
    private_md_size::UInt64
    bitcode_offset::UInt64
    bitcode_size::UInt64
end

function show(io::IO, header::MetallibHeader)
    println(io, "Metallib Header")
    println(io, "  Target ", header.target)
    println(io, "  Version ", header.ver_major, ".", header.ver_minor)
    println(io, "  File Type ", header.filetype)
    println(io, "  Target OS ", header.target_os)
    println(io, "  OS Version ", header.os_major, ".", header.os_minor)
    println(io, "  Size ", Base.format_bytes(header.size))
    println(io, "  Function List ", Base.format_bytes(header.funclist_size), " at 0x", string(header.funclist_offset; base=16))
    println(io, "  Public Metadata ", Base.format_bytes(header.public_md_size), " at 0x", string(header.public_md_offset; base=16))
    println(io, "  Private Metadata ", Base.format_bytes(header.private_md_size), " at 0x", string(header.private_md_offset; base=16))
    println(io, "  Bitcode ", Base.format_bytes(header.bitcode_size), " at 0x", string(header.bitcode_offset; base=16))
end
