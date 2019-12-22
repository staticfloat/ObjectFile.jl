using Documenter, ObjectFile

makedocs(modules = [ObjectFile],
         sitename = "ObjectFile.jl",
         pages = [
            "Home" => "index.md"
         ]
)

deploydocs(
    repo = "github.com/staticfloat/ObjectFile.jl.git",
    target = "build"
)
