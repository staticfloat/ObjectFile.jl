export COFFOptionalHeaderStandard, COFFImageDataDirectory, COFFDataDirectories,
       COFFOptionalHeaderWindows32, COFFOptionalHeaderWindows64,
       COFFOptionalHeader32, COFFOptionalHeader64

@io struct COFFOptionalHeaderStandard
    Magic::UInt16
    MajorLinkerVersion::UInt8
    MinorLinkerVersion::UInt8
    SizeOfCode::UInt32
    SizeOfInitializedData::UInt32
    SizeOfUninitializedData::UInt32
    AddressOfEntryPoint::UInt32
    BaseOfCode::UInt32
end
const OPTHEADER_STANDARD_MAGIC32 = 0x10b
const OPTHEADER_STANDARD_MAGIC64 = 0x20b

@io struct COFFImageDataDirectory
    VirtualAddress::UInt32
    Size::UInt32
end

@io struct COFFDataDirectories
    ExportTable::COFFImageDataDirectory
    ImportTable::COFFImageDataDirectory
    ResourceTable::COFFImageDataDirectory
    ExceptionTable::COFFImageDataDirectory
    CertificateTable::COFFImageDataDirectory
    BaseRelocatioNTable::COFFImageDataDirectory
    Debug::COFFImageDataDirectory
    Architecture::COFFImageDataDirectory
    GlobalPtr::COFFImageDataDirectory
    TLSTable::COFFImageDataDirectory
    LoadConfigTable::COFFImageDataDirectory
    BoundImport::COFFImageDataDirectory
    IAT::COFFImageDataDirectory
    DelayImportDescriptor::COFFImageDataDirectory
    CLRRuntimeHeader::COFFImageDataDirectory
    Reserverd::COFFImageDataDirectory
end

@io struct COFFOptionalHeaderWindows32
    ImageBase::UInt32
    SectionAlignment::UInt32
    FileAlignment::UInt32
    MajorOperatingSystemVersion::UInt16
    MinorOperatingSystemVersion::UInt16
    MajorImageVersion::UInt16
    MinorImageVersion::UInt16
    MajorSubsystemVersion::UInt16
    MinorSubsystemVersion::UInt16
    Win32VersionValue::UInt32
    SizeOfImage::UInt32
    SizeOfHeaders::UInt32
    CheckSum::UInt32
    Subsystem::UInt16
    DllCharacteristics::UInt16
    SizeOfStackReserve::UInt32
    SizeOfStackCommit::UInt32
    SizeOfHeapReserve::UInt32
    SizeOfHeapCommit::UInt32
    LoaderFlag::UInt32
    NumberOfRvaAndSizes::UInt32
end

@io struct COFFOptionalHeaderWindows64
    ImageBase::UInt64
    SectionAlignment::UInt32
    FileAlignment::UInt32
    MajorOperatingSystemVersion::UInt16
    MinorOperatingSystemVersion::UInt16
    MajorImageVersion::UInt16
    MinorImageVersion::UInt16
    MajorSubsystemVersion::UInt16
    MinorSubsystemVersion::UInt16
    Win32VersionValue::UInt32
    SizeOfImage::UInt32
    SizeOfHeaders::UInt32
    CheckSum::UInt32
    Subsystem::UInt16
    DllCharacteristics::UInt16
    SizeOfStackReserve::UInt64
    SizeOfStackCommit::UInt64
    SizeOfHeapReserve::UInt64
    SizeOfHeapCommit::UInt64
    LoaderFlag::UInt32
    NumberOfRvaAndSizes::UInt32
end

abstract type COFFOptionalHeader end
@io struct COFFOptionalHeader32 <: COFFOptionalHeader
    standard::COFFOptionalHeaderStandard
    BaseOfData::UInt32
    windows::COFFOptionalHeaderWindows32
    directories::COFFDataDirectories
end

@io struct COFFOptionalHeader64 <: COFFOptionalHeader
    standard::COFFOptionalHeaderStandard
    windows::COFFOptionalHeaderWindows64
    directories::COFFDataDirectories
end

function read(io::IO, ::Type{COFFOptionalHeader})
    # First, unpack the standard bits
    standard = unpack(io, COFFOptionalHeaderStandard)

    # If it's a 32-bit header, read that out, otherwise, do the 64-bit dance
    if standard.Magic == OPTHEADER_STANDARD_MAGIC32
        BaseOfData = read(io, UInt32)
        windows = unpack(io, COFFOptionalHeaderWindows32)
        dirs = unpack(io, COFFDataDirectories)
        return COFFOptionalHeader32(standard, BaseOfData, windows, dirs)
    elseif standard.Magic == OPTHEADER_STANDARD_MAGIC64
        windows = unpack(io, COFFOptionalHeaderWindows64)
        dirs = unpack(io, COFFDataDirectories)
        return COFFOptionalHeader64(standard, windows, dirs)
    else
        error("Unknown COFF optional header magic 0x$(string(standard.Magic, base=16))")
    end
end

