# psi can be either Array{ComplexF64,1} (single columns)
# or Array{ComplexF64,2} (multicolumn)
# This is handled by individual op_* functions
function op_H( Ham::Hamiltonian, psi )
    if Ham.pspotNL.NbetaNL > 0
        return op_K(Ham, psi) + op_V_Ps_loc(Ham, psi) + op_V_Ps_nloc(Ham, psi)
        return op_K( Ham, psi ) + op_V_loc( Ham, psi ) + op_V_Ps_nloc( Ham, psi )
    else
        return op_K(Ham, psi) + op_V_Ps_loc(Ham, psi)
        return op_K( Ham, psi ) + op_V_loc( Ham, psi )
    end
end

import Base: *
*( Ham::Hamiltonian, psi ) = op_H( Ham, psi )
*( psi::LinearAlgebra.Adjoint{Complex{Float64},Array{Complex{Float64},2}},
   Ham::Hamiltonian ) = adjoint( op_H( Ham, adjoint(psi) ) )
