import InteractiveUtils
using Printf
using Random
using BenchmarkTools
using PWDFT

println()
InteractiveUtils.versioninfo()

const Nargs = length(ARGS)

if Nargs == 0
    const FILELIST = [
        "time_gen_lattice.jl",
        "time_Atoms.jl",
        "time_PWGrid.jl",
        "time_Hamiltonian.jl",
        "time_op_kpt_1.jl"
    ]    
    for fil in FILELIST
        include(fil)
    end
else
    include(ARGS[1])
end