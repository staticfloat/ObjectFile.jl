using Base.Meta
export @mustimplement, @derefmethod, @constants,
       read_struct, getindex_ref

"""
    @mustimplement

Macro to create fallthrough implementations of basic functions such as
`readheader(oh::ObjectHandle)`; these fallthrough implementations are meant to
be overridden by methods in packages such as `ELF.jl` or `MachO.jl`.
"""
macro mustimplement(sig)
    # Get information about the signature, including the type of the first
    # argument, which is typically the name of the relevant object.
    fname = sig.args[1]
    arg1 = sig.args[2]
    if isa(arg1, Expr)
        arg1 = arg1.args[1]
    end

    # Generate a method that just gives an error
    return quote
        $(esc(sig)) = error(typeof($(esc(arg1))), " must implement $($(fname))")
    end
end

"""
    @derefmethod

Macro to create a method that works on a reference type by generating a wrapper
call to `deref(x)` where `x` is the first argument in the call.  Example:

    @derefmethod foo(x::SectionRef)

Will generate the following code:

    foo(x::SectionRef, args...) = foo(deref(x), args...)
"""
macro derefmethod(sig)
    # Given an Expression, continually unwrap `:where` expressions
    function unwrap_where(e)
        while e.head == :where
            e = e.args[1]
        end
        return e
    end

    # Given an Expression, wrap it in `:where` expressions so that it has
    # the same UnionAll-ness as the original expression
    function rewrap_where(e, orig_e)
        if orig_e.head == :where
            e = rewrap_where(e, orig_e.args[1])
            e = Expr(:where, e, orig_e.args[2])
        end
        return e
    end

    # Get information from the method like the name of the first argument.
    func_sig = unwrap_where(sig)
    fname = func_sig.args[1]
    x_arg = func_sig.args[2]

    if isa(x_arg, Expr) && x_arg.head == :(::)
        x_arg = x_arg.args[1]
    end

    # Generate a method that calls another method with the same name, but with
    # the first argument passed through `deref()` first. Preserve UnionAll-ness
    # by recreating it, if necessary:
    lhs = :($(fname)($(func_sig.args[2]), args...))
    rhs = :($(fname)(deref($(x_arg)), args...))
    return esc(:($(rewrap_where(lhs, sig)) = $(rhs)))
end


"""
    @constants

Macro to create intelligent enum arrays in Julia.  Defines not only variables
mapping names to values within Julia, but also a dictionary mapping those
values back to a string representation of the variable names itself.
"""
macro constants(array, stripprefix, expr)
    # We will build up a chunk of code, we'll call that `ret`
    ret = Expr(:block)

    # Initialize the name lookup array
    push!(ret.args,:(const $array = Dict{UInt32,String}()))

    for e in expr.args
        # If it's not a `const` expression, skip it
        if !isexpr(e,:const)
            continue
        end
        
        # Ensure this `const` expression is assigning something
        eq = e.args[1]
        @assert isexpr(eq,:(=))

        # Strip out the prefix so our names are more interesting
        name = string(eq.args[1])
        name = replace(name, stripprefix => "", count=1)

        # Define the value, then slip its stripped prefix name into the name
        # lookup array right afterwards.
        push!(ret.args,e)
        push!(ret.args,:($array[UInt32($(eq.args[1]))] = $name))
    end

    # Return `ret`, the chunk of code we've built up
    return esc(ret)
end

"""
    read_struct(oh, type_func, size_func, name)

Given a `Type`, (such as `ELFSection64`), `unpack()` it from the given object
and return it, throwing errors as appropriate, and skipping over any excess
padding bytes as determined by `type_func` and `size_func`. Example invocation:

read_struct(oh, symtab_entry_type, symtab_entry_size, "Symbol Entry")
"""
function read_struct(oh, type_func, size_func, name)
    # Get calculated types and sizes
    ST = type_func(oh)
    max_size = size_func(oh)

    # Get the size of the object we're going to read in in memory
    calc_size = Core.sizeof(ST)

    # If that's larger than what the ELF object has, fail out
    if calc_size > max_size
        msg = strip("""
        Reported $(name) size ($(max_size) is smaller
        than calculated $(name) size ($(calc_size))
        """)
        error(replace(msg, "\n" => " "))
    end

    # If it's less than or equal to, read it in, then skip past extra data we
    # don't care about (future extensions to the ELF format, for instance)
    val = unpack(oh, ST)
    skip(oh, max_size - calc_size)

    # Return our ill-gotten goods
    return val
end


"""
    getindex_ref(collection, offset, stride, T, ref_type, idx)

Given a `collection`, such as `Sections`, `DynamicLinks`, etc... use the given
`offset`, `stride`, and `T` parameters to read in and construct a `ref_type`
object located at index `idx`.  Example invocation:

    getindex_ref(
        sections,
        section_header_offset(oh),
        section_header_size(oh),
        section_header_type(oh),
        SectionRef,
        idx
    )
"""
function getindex_ref(collection, offset, stride, T, ref_type, idx)
    # Ensure we're within the correct range
    if !(0 < idx <= length(collection))
        throw(BoundsError(collection, idx))
    end
    
    # If we are, seek, read it in, and return
    oh = handle(collection)
    seek(oh, offset + (idx-1)*stride)
    val = unpack(oh, T)

    # Return a SectionRef, as that's the more general object
    return ref_type(collection, val, idx)
end