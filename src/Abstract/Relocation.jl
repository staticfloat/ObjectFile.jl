abstract type Relocation{T<:ObjectHandle} end
abstract type RelocationRef{T<:ObjectHandle} end


struct LOIByName
    addrs::Dict{Symbol, UInt64}
end
function getSectionLoadAddress(LOI::LOIByName, x::Union{Symbol, AbstractString})
    return LOI.addrs[symbol(x)]
end
function getSectionLoadAddress(LOI::LOIByName, sec)
    return getSectionLoadAddress(LOI, bytestring(sectionname(sec)))
end
