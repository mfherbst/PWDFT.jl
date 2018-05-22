function KS_solve_SCF!( Ham::PWHamiltonian ;
                       startingwfc=nothing, savewfc=true,
                       β = 0.5, NiterMax=100, verbose=false,
                       check_rhoe_after_mix=false,
                       update_psi="LOBPCG", cheby_degree=8,
                       mix_method="simple",
                       ETOT_CONV_THR=1e-6 )

    pw = Ham.pw
    Ngw = pw.gvecw.Ngw
    kpoints = pw.gvecw.kpoints
    Nkpt = kpoints.Nkpt
    Ns = pw.Ns
    Npoints = prod(Ns)
    dVol = pw.Ω/Npoints
    Focc = Ham.electrons.Focc
    Nstates = Ham.electrons.Nstates
    Nspin = Ham.electrons.Nspin
    Nkspin = Nkpt*Nspin

    psiks = Array{Array{Complex128,2},1}(Nkspin)

    #
    # Random guess of wave function
    #
    if startingwfc==nothing
        srand(1234)
        for ispin = 1:Nspin
        for ik = 1:Nkpt
            ikspin = ik + (ispin - 1)*Nkpt
            psi = rand(Ngw[ik],Nstates) + im*rand(Ngw[ik],Nstates)
            psiks[ikspin] = ortho_gram_schmidt(psi)
        end
        end
    else
        psiks = startingwfc
    end

    #
    # Calculated electron density from this wave function and update Hamiltonian
    #
    Rhoe = zeros(Float64,Npoints,Nspin)
    for ispin = 1:Nspin
        idxset = (Nkpt*(ispin-1)+1):(Nkpt*ispin)
        Rhoe[:,ispin] = calc_rhoe( pw, Focc[:,idxset], psiks[idxset] )
    end
    update!(Ham, Rhoe)

    Etot_old = 0.0

    Rhoe_new = zeros(Float64,Npoints,Nspin)

    diffRhoe = zeros(Nspin)

    evals = zeros(Float64,Nstates,Nkspin)

    const ETHR_EVALS_LAST = 1e-6

    ethr = 0.1

    #
    # For Anderson mixing
    #
    MIXDIM = 4
    if mix_method == "anderson"
        df = zeros(Float64,Npoints,MIXDIM,Nspin)
        dv = zeros(Float64,Npoints,MIXDIM,Nspin)
    end

    @printf("\n")
    @printf("Self-consistent iteration begins ...\n")
    if mix_method == "anderson"
        @printf("Using Anderson mixing\n")
    else
        @printf("Using simple mixing\n")
    end
    @printf("Density mixing with β = %10.5f\n", β)
    @printf("\n")

    for iter = 1:NiterMax

        if update_psi == "LOBPCG"
            for ispin = 1:Nspin
            for ik = 1:Nkpt
                Ham.ik = ik
                Ham.ispin = ispin
                ikspin = ik + (ispin - 1)*Nkpt
                #
                evals[:,ikspin], psiks[ikspin] =
                diag_lobpcg( Ham, psiks[ikspin], verbose_last=false )
                #
            end
            end

        elseif update_psi == "PCG"
            
            # determined convergence criteria for diagonalization
            if iter == 1
                ethr = 0.1
            elseif iter == 2
                ethr = 0.01
            else
                ethr = ethr/5.0
                ethr = max( ethr, ETHR_EVALS_LAST )
            end

            for ik = 1:Nkpt
                Ham.ik = ik
                Ham.ispin = ispin
                ikspin = ik + (ispin - 1)*Nkpt
                evals[:,ikspin], psiks[ikspin] = diag_Emin_PCG( Ham, psiks[ikspin], TOL_EBANDS=ethr )
            end

        elseif update_psi == "CheFSI"
            
            for ik = 1:Nkpt
                Ham.ik = ik
                Ham.ispin = ispin
                ikspin = ik + (ispin - 1)*Nkpt
                ub, lb = get_ub_lb_lanczos( Ham, Nstates*2 )
                psiks[ikspin] = chebyfilt( Ham, psiks[ikspin], cheby_degree, lb, ub)
                psiks[ikspin] = ortho_gram_schmidt( psiks[ik] )
            end

        end

        for ispin = 1:Nspin
            idxset = (Nkpt*(ispin-1)+1):(Nkpt*ispin)
            Rhoe_new[:,ispin] = calc_rhoe( pw, Focc[:,idxset], psiks[idxset] )
            diffRhoe[ispin] = norm(Rhoe_new[:,ispin] - Rhoe[:,ispin])
        end

        if mix_method == "simple"
            for ispin = 1:Nspin
                Rhoe[:,ispin] = β*Rhoe_new[:,ispin] + (1-β)*Rhoe[:,ispin]
            end
        elseif mix_method == "anderson"
            # FIXME: df and dv is not modified when we call it by df[:,:] or dv[:,:]
            Rhoe[:,:] = andersonmix!( Rhoe, Rhoe_new, β, df, dv, iter, MIXDIM )
        else
            @printf("ERROR: Unknown mix_method = %s\n", mix_method)
            exit()
        end

        for ispin = 1:Nspin
            for ip = 1:Npoints
                if Rhoe[ip,ispin] < 1e-12
                    Rhoe[ip,ispin] = 1e-12
                end
            end
        end

        if check_rhoe_after_mix
            integRhoe = sum(Rhoe)*dVol
            @printf("After mixing: integRho = %18.10f\n", integRhoe)
        end

        update!( Ham, Rhoe )

        # Calculate energies
        Ham.energies = calc_energies( Ham, psiks )
        Etot = Ham.energies.Total
        diffE = abs( Etot - Etot_old )

        if Nspin == 1
            @printf("SCF: %8d %18.10f %18.10e %18.10e\n",
                    iter, Etot, diffE, diffRhoe[1] )
        else
            @printf("SCF: %8d %18.10f %18.10e %18.10e %18.10e\n",
                    iter, Etot, diffE, diffRhoe[1], diffRhoe[2] )
        end

        if diffE < ETOT_CONV_THR
            @printf("SCF is converged: iter: %d , diffE = %10.7e\n", iter, diffE)
            break
        end
        #
        Etot_old = Etot
    end

    # Eigenvalues are not calculated if using CheFSI.
    # We calculate them here.
    if update_psi == "CheFSI"
        for ispin = 1:Nspin
        for ik = 1:Nkpt
            Ham.ik = ik
            Ham.ispin = ispin
            ikspin = ik + (ispin - 1)*Nkpt
            Hr = psik[ikspin]' * op_H( Ham, psiks[ikspin] )
            evals[:,ikspin] = real(eigvals(Hr))
        end
        end
    end

    Ham.electrons.ebands = evals

    if savewfc
        for ikspin = 1:Nkpt*Nspin
            wfc_file = open("WFC_ikspin_"*string(ikspin)*".data","w")
            write( wfc_file, psiks[ikspin] )
            close( wfc_file )
        end
    end

    return

end
