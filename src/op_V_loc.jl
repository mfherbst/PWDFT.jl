function op_V_loc( Ham::Hamiltonian, psiks::BlochWavefunc )
    Nstates = size(psiks[1])[2] # Nstates should be similar for all Bloch states
    Nspin = Ham.electrons.Nspin
    Nkpt = Ham.pw.gvecw.kpoints.Nkpt
    out = zeros_BlochWavefunc(Ham)
    
    for ispin = 1:Nspin
    for ik=1:Nkpt
        Ham.ik = ik
        Ham.ispin = ispin
        ikspin = ik + (ispin - 1)*Nkpt
        out[ikspin] = op_V_loc( Ham, psiks[ikspin] )
    end
    end
    return out
end

function op_V_Ps_loc( Ham::Hamiltonian, psiks::BlochWavefunc )
    Nstates = size(psiks[1])[2] # Nstates should be similar for all Bloch states
    Nspin = Ham.electrons.Nspin
    Nkpt = Ham.pw.gvecw.kpoints.Nkpt
    out = zeros_BlochWavefunc(Ham)
    
    for ispin = 1:Nspin
    for ik=1:Nkpt
        Ham.ik = ik
        Ham.ispin = ispin
        ikspin = ik + (ispin - 1)*Nkpt
        out[ikspin] = op_V_Ps_loc( Ham, psiks[ikspin] )
    end
    end
    return out
end

# apply V_Ps_loc, Hartree, and XC potentials
function op_V_loc( Ham::Hamiltonian, psi::Array{ComplexF64,2} )
    ispin = Ham.ispin
    ik = Ham.ik
    V_loc = Ham.potentials.Ps_loc
    return op_V_loc( ik, Ham.pw, V_loc, psi )
end

# only apply V_Ps_loc
function op_V_Ps_loc( Ham::Hamiltonian, psi::Array{ComplexF64,2} )
    return op_V_loc( Ham.ik, Ham.pw, Ham.potentials.Ps_loc, psi )
end

# apply general V_loc
# ik must be given to get information about
# mapping between psi in G-space to real space
function op_V_loc( ik::Int64, pw::PWGrid, V_loc::Array{Float64,1}, psi::Array{ComplexF64,2} )
    Ns = pw.Ns
    CellVolume  = pw.CellVolume
    Npoints = prod(Ns)
    Nstates = size(psi)[2]

    ctmp = zeros(ComplexF64, Npoints, Nstates)
    idx = pw.gvecw.idx_gw2r[ik]
    for ist = 1:Nstates
        ctmp[idx,ist] = psi[:,ist]
    end

    # get values of psi in real space grid via forward transform
    G_to_R!(pw, ctmp)

    for ist = 1:Nstates
        for ip = 1:Npoints
            ctmp[ip,ist] = V_loc[ip]*ctmp[ip,ist]
        end
    end

    R_to_G!(pw, ctmp)
    return ctmp[idx,:]
end

#
# single-column version
#
function op_V_loc( Ham::Hamiltonian, psi::Array{ComplexF64,1} )
    ispin = Ham.ispin
    V_loc = Ham.potentials.Ps_loc
    return op_V_loc( Ham.ik, Ham.pw, V_loc, psi )
end

function op_V_Ps_loc( Ham::Hamiltonian, psi::Array{ComplexF64,1} )
    return op_V_loc( Ham.ik, Ham.pw, Ham.potentials.Ps_loc, psi )
end

function op_V_loc( ik::Int64, pw::PWGrid, V_loc::Array{Float64,1}, psi::Array{ComplexF64,1} )
    Ns = pw.Ns
    CellVolume  = pw.CellVolume
    Npoints = prod(Ns)

    ctmp = zeros(ComplexF64, Npoints)
    idx = pw.gvecw.idx_gw2r[ik]
    ctmp[idx] = psi[:]

    # get values of psi in real space grid via forward transform
    ctmp = G_to_R( pw, ctmp )

    for ip = 1:Npoints
        ctmp[ip] = V_loc[ip]*ctmp[ip]
    end

    cVpsi = R_to_G( pw, ctmp )
    return cVpsi[idx]
end

