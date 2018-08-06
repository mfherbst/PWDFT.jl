using Printf
using Random
using LinearAlgebra

using PWDFT

include("alt1_KS_solve_SCF.jl")
include("../src/mix_rpulay.jl")
include("alt1_KS_solve_SCF_spinpol.jl")

function create_Hamiltonian_H_atom()
    # Atoms
    atoms = init_atoms_xyz_string(
        """
        1

        H  0.0  0.0  0.0
        """)
    atoms.LatVecs = gen_lattice_sc(16.0)
    println(atoms)

    # Initialize Hamiltonian
    pspfiles = ["../pseudopotentials/pade_gth/H-q1.gth"]
    ecutwfc_Ry = 30.0
    Ham = Hamiltonian( atoms, pspfiles, ecutwfc_Ry*0.5, verbose=true )

    # calculate E_NN
    Ham.energies.NN = calc_E_NN( atoms )

    return Ham
end

function create_Hamiltonian_H2()
    # Atoms
    atoms = init_atoms_xyz("../structures/H2.xyz")
    atoms.LatVecs = gen_lattice_sc(16.0)
    println(atoms)

    # Initialize Hamiltonian
    pspfiles = ["../pseudopotentials/pade_gth/H-q1.gth"]
    ecutwfc_Ry = 30.0
    Ham = Hamiltonian( atoms, pspfiles, ecutwfc_Ry*0.5, verbose=true )

    # calculate E_NN
    Ham.energies.NN = calc_E_NN( atoms )

    return Ham
end

function create_Hamiltonian_N2()
    # Atoms
    atoms = init_atoms_xyz("../structures/N2.xyz")
    atoms.LatVecs = gen_lattice_cubic(16.0)
    println(atoms)

    # Initialize Hamiltonian
    ecutwfc_Ry = 30.0
    pspfiles = ["../pseudopotentials/pade_gth/N-q5.gth"]
    Ham = Hamiltonian( atoms, pspfiles, ecutwfc_Ry*0.5 )

    # calculate E_NN
    Ham.energies.NN = calc_E_NN( atoms )

    return Ham
end


function create_Hamiltonian_O2()
    # Atoms
    atoms = init_atoms_xyz("../structures/O2.xyz")
    atoms.LatVecs = gen_lattice_sc(16.0)
    println(atoms)

    # Initialize Hamiltonian
    pspfiles = ["../pseudopotentials/pade_gth/O-q6.gth"]
    ecutwfc_Ry = 30.0
    Ham = Hamiltonian( atoms, pspfiles, ecutwfc_Ry*0.5, verbose=true, extra_states=1 )
    Ham.electrons.Focc[:,1] = [2.0, 2.0, 2.0, 2.0, 2.0, 1.0, 1.0]

    println(Ham.electrons)

    # calculate E_NN
    Ham.energies.NN = calc_E_NN( atoms )

    return Ham
end


function create_Hamiltonian_N2()
    # Atoms
    atoms = init_atoms_xyz("../structures/N2.xyz")
    atoms.LatVecs = gen_lattice_sc(16.0)
    println(atoms)

    # Initialize Hamiltonian
    ecutwfc_Ry = 30.0
    pspfiles = ["../pseudopotentials/pade_gth/N-q5.gth"]
    Ham = Hamiltonian( atoms, pspfiles, ecutwfc_Ry*0.5, extra_states=1, verbose=true )

    # calculate E_NN
    Ham.energies.NN = calc_E_NN( atoms )

    return Ham
end

function create_Hamiltonian_Co_atom()
    atoms = Atoms(xyz_string="""
    1

    Co   0.0   0.0   0.0
    """, LatVecs=gen_lattice_sc(16.0))
    println(atoms)

    # Initialize Hamiltonian
    ecutwfc_Ry = 30.0
    pspfiles = ["../pseudopotentials/pade_gth/Co-q9.gth"]
    Ham = Hamiltonian(
        atoms, pspfiles, ecutwfc_Ry*0.5, verbose=true, Nspin=2, extra_states=1
        )
    Ham.electrons.Focc[:,1] = [1.0, 1.0, 1.0, 1.0, 1.0, 0.0]
    Ham.electrons.Focc[:,2] = [1.0, 1.0, 1.0, 1.0, 0.0, 0.0]

    println("\nFocc is set manually\n")
    println(Ham.electrons)

    # calculate E_NN
    Ham.energies.NN = calc_E_NN( atoms )

    return Ham
end


function test_main()

    #Ham = create_Hamiltonian_H_atom()
    #Ham = create_Hamiltonian_H2()
    #Ham = create_Hamiltonian_N2()
    #Ham = create_Hamiltonian_O2()
    Ham = create_Hamiltonian_Co_atom()

    # Solve the KS problem
    #@time alt1_KS_solve_SCF!(
    #    Ham, ETOT_CONV_THR=1e-6, NiterMax=50, betamix=0.5, update_psi="LOBPCG"
    #)
    @time alt1_KS_solve_SCF_spinpol!(
        Ham, ETOT_CONV_THR=1e-6, NiterMax=10, betamix=0.1, update_psi="LOBPCG"
    )

    #@time KS_solve_SCF_spin!(
    #    Ham, ETOT_CONV_THR=1e-6, NiterMax=50, betamix=0.5, update_psi="LOBPCG"
    #)

    
    Nstates = Ham.electrons.Nstates
    ebands = Ham.electrons.ebands
    
    println("\nBand energies:")
    for ist = 1:Nstates
        @printf("%8d  %18.10f = %18.10f eV\n", ist, ebands[ist], ebands[ist]*Ry2eV*2)
    end
    
    println("\nTotal energy components")
    println(Ham.energies)
end

test_main()
