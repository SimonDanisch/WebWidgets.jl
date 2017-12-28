# Setup
# very simple implementation for isinstalled which should be enough for our purposes
isinstalled(pkg) = isdir(Pkg.dir(pkg))

installgizmo(pkg) = isinstalled(pkg) || Pkg.clone("https://github.com/JuliaGizmos/$(pkg).jl")

installgizmo("WebIO")
Pkg.checkout("Observables")
installgizmo("Vue")
installgizmo("CSSUtil")
installgizmo("InteractNext")
asset_dir = Pkg.dir("WebWidgets", "assets")
wio_asset_dir = Pkg.dir("WebIO", "assets")
for elem in readdir(asset_dir)
    file_source = joinpath(asset_dir, elem)
    file_target = joinpath(wio_asset_dir, elem)
    if !(isfile(file_target) || isdir(file_target))
        try
            println("Copying: $file_target")
            cp(file_source, file_target)
        catch e
            warn(e)
        end
    end
end
