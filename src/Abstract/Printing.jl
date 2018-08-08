"""
    show_collection(io, collection, ::Type{H<:ObjectHandle})

Given a collection-like object, (`Symbols`, `DynamicLinks`, ``)
"""
function show_collection(io::IO, stuff::ST, ::Type{H}) where {ST} where {H <: ObjectHandle}
    h_str = format_string(H)

    # Get the type name, removing the `ELF`/`MachO`/`COFF` at the beginning
    type_name = if isa(ST, UnionAll)
        string(ST.body.name.name)
    else
        string(ST.name.name)
    end

    if startswith(type_name, h_str)
        type_name = type_name[length(h_str)+1:end]
    end

    # Start by outputting the container type
    print(io, h_str," ", type_name)

    # Next, print either the entire thing, or a limited subsection of it
    limited = get(io, :limit, false)
    if limited && length(stuff) > 20
        for idx in 1:10
            print(io, "\n  [$(idx)] ")
            show(IOContext(io, :compact => true), stuff[idx])
        end
        print(io, "\n   \u2026")
        for idx in length(stuff)-10:length(stuff)
            print(io, "\n  [$(idx)] ")
            show(IOContext(io, :compact => true), stuff[idx])
        end
    else
        for idx in 1:length(stuff)
            print(io, "\n  [$(idx)] ")
            show(IOContext(io, :compact => true), stuff[idx])
        end
    end
end
