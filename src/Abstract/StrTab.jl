# Export StrTab API
export StrTab,
       handle, strtab_lookup

"""
    StrTab

This type encapsulates a string table within an object file, enabling queries
against the string table for symbol names, section names, etc... The list of
available API operations is given below, with methods that subclasses must
implement marked in emphasis:

### Creation
  - *StrTab()*

### Accessors
  - *handle()*
  - *strtab_lookup()*
"""
abstract type StrTab{H <: ObjectHandle} end


"""
    handle(s::StrTab)

Return the `ObjectHandle` this `StrTab` belongs to.
"""
@mustimplement handle(strtab::StrTab)

"""
    strtab_lookup(s::StrTab, index)

Reads a string from the given `StrTab` at `index`.
"""
@mustimplement strtab_lookup(s::StrTab, index)