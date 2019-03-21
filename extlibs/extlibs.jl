if VERSION >= v"0.7.0-DEV.3382"
    using Libdl
end

macro checked_lib(libname, path)
    if Libdl.dlopen_e(eval(path)) == C_NULL
        error("Unable to load \n\n$libname ($path)\n\n")
    end
    quote
        const $(esc(libname)) = $path
    end
end


@checked_lib LIBXC joinpath(@__DIR__, "libxc.so")
@checked_lib LIBSYMSPG joinpath(@__DIR__, "libsymspg.so")
