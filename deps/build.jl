# Setup
# very simple implementation for isinstalled which should be enough for our purposes
isinstalled(pkg) = isdir(Pkg.dir(pkg))

installgizmo(pkg) = isinstalled(pkg) || Pkg.clone("https://github.com/JuliaGizmos/$(pkg).jl")

installgizmo("CSSUtil")
installgizmo("InteractNext")
