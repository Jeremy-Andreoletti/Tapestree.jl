#=

Anagenetic GBM birth-death MCMC using forward simulation

Ignacio Quintero Mächler

t(-_-t)

Created 03 09 2020
=#




"""
    insane_gbmce(tree    ::sT_label, 
                 out_file::String;
                 λa_prior::NTuple{2,Float64} = (0.0, 100.0),
                 α_prior ::NTuple{2,Float64} = (0.0, 10.0),
                 σλ_prior::NTuple{2,Float64} = (0.05, 0.05),
                 μ_prior ::NTuple{2,Float64} = (1.0, 1.0),
                 niter   ::Int64             = 1_000,
                 nthin   ::Int64             = 10,
                 nburn   ::Int64             = 200,
                 marginal::Bool              = false,
                 nitpp   ::Int64             = 100, 
                 nthpp   ::Int64             = 10,
                 K       ::Int64             = 11,
                 λi      ::Float64           = NaN,
                 αi      ::Float64           = 0.0,
                 σλi     ::Float64           = 0.01,
                 μi      ::Float64           = NaN,
                 ϵi      ::Float64           = 0.2,
                 pupdp   ::NTuple{5,Float64} = (0.1,0.1,0.1,0.2,0.2),
                 nlim    ::Int64             = 500,
                 δt      ::Float64           = 1e-2,
                 prints  ::Int64             = 5,
                 tρ      ::Dict{String, Float64} = Dict("" => 1.0))

Run insane for `gbm-ce`.
"""
function insane_gbmce(tree    ::sT_label, 
                      out_file::String;
                      λa_prior::NTuple{2,Float64} = (0.0, 100.0),
                      α_prior ::NTuple{2,Float64} = (0.0, 10.0),
                      σλ_prior::NTuple{2,Float64} = (0.05, 0.05),
                      μ_prior ::NTuple{2,Float64} = (1.0, 1.0),
                      niter   ::Int64             = 1_000,
                      nthin   ::Int64             = 10,
                      nburn   ::Int64             = 200,
                      marginal::Bool              = false,
                      nitpp   ::Int64             = 100, 
                      nthpp   ::Int64             = 10,
                      K       ::Int64             = 11,
                      λi      ::Float64           = NaN,
                      αi      ::Float64           = 0.0,
                      σλi     ::Float64           = 0.01,
                      μi      ::Float64           = NaN,
                      ϵi      ::Float64           = 0.2,
                      pupdp   ::NTuple{5,Float64} = (0.1,0.1,0.1,0.2,0.2),
                      nlim    ::Int64             = 500,
                      δt      ::Float64           = 1e-2,
                      prints  ::Int64             = 5,
                      tρ      ::Dict{String, Float64} = Dict("" => 1.0))

  # `n` tips, `th` treeheight define δt
  n    = ntips(tree)
  th   = treeheight(tree)
  δt  *= max(0.1, round(th, RoundDown, digits = 2))
  srδt = sqrt(δt)

  # set tips sampling fraction
  if isone(length(tρ))
    tl = tiplabels(tree)
    tρu = tρ[""]
    tρ = Dict(tl[i] => tρu for i in 1:n)
  end

  # make fix tree directory
  idf = make_idf(tree, tρ)

   # starting parameters (using method of moments)
  if isnan(λi) && isnan(μi)
    λc, μc = moments(Float64(n), ti(idf[1]), ϵi)
  else
    λc, μc = λi, μi
  end

  # make a decoupled tree
  Ξ = iTgbmce[]
  iTgbmce!(Ξ, tree, δt, srδt, log(λc), αi, σλi)

  # set end of fix branch speciation times and
  # get vector of internal branches
  inodes = Int64[]
  for i in Base.OneTo(lastindex(idf))
    bi = idf[i]
    setλt!(bi, lλ(Ξ[i])[end])
    if !it(bi)
      push!(inodes, i)
    end
  end

  # parameter updates (1: α, 2: σλ, 3: μ, 4: gbm, 5: forward simulation)
  spup = sum(pupdp)
  pup  = Int64[]
  for i in Base.OneTo(5) 
    append!(pup, fill(i, ceil(Int64, Float64(2*n - 1) * pupdp[i]/spup)))
  end

  # conditioning functions
  sns = (BitVector(), BitVector(), BitVector())
  snodes! = make_snodes(idf, !iszero(e(tree)), iTgbmce)
  snodes!(Ξ, sns)
  scond, scond0 = make_scond(idf, !iszero(e(tree)), iTgbmce)

  @info "running birth-death gbm with constant μ"

  # burn-in phase
  Ξ, idf, llc, prc, αc, σλc, μc, sns =
    mcmc_burn_gbmce(Ξ, idf, λa_prior, α_prior, σλ_prior, μ_prior, 
      nburn, αi, σλi, μc, sns, δt, srδt, inodes, pup, 
      prints, snodes!, scond, scond0)

  # mcmc
  R, Ξv =
    mcmc_gbmce(Ξ, idf, llc, prc, αc, σλc, μc, sns,
      λa_prior, α_prior, σλ_prior, μ_prior, niter, nthin, δt, srδt, 
      inodes, pup, prints, snodes!, scond, scond0)

  pardic = Dict(("lambda_root"  => 1,
                 "alpha"        => 2,
                 "sigma_lambda" => 3,
                 "mu"           => 4))

  write_ssr(R, pardic, out_file)

  return R, Ξv
end




"""
    mcmc_burn_gbmce(Ξ       ::Vector{iTgbmce},
                    idf     ::Vector{iBffs},
                    λa_prior::NTuple{2,Float64},
                    α_prior ::NTuple{2,Float64},
                    σλ_prior::NTuple{2,Float64},
                    μ_prior ::NTuple{2,Float64},
                    nburn   ::Int64,
                    tune_int::Int64,
                    αc      ::Float64,
                    σλc     ::Float64,
                    μc      ::Float64,
                    μtn     ::Float64,
                    δt      ::Float64,
                    srδt    ::Float64,
                    pup     ::Array{Int64,1},
                    prints  ::Int64,
                    scalef  ::Function,
                    snodes! ::Function,
                    scond   ::Function,
                    scond0  ::Function)

MCMC burn-in chain for `gbmce`.
"""
function mcmc_burn_gbmce(Ξ       ::Vector{iTgbmce},
                         idf     ::Vector{iBffs},
                         λa_prior::NTuple{2,Float64},
                         α_prior ::NTuple{2,Float64},
                         σλ_prior::NTuple{2,Float64},
                         μ_prior ::NTuple{2,Float64},
                         nburn   ::Int64,
                         αc      ::Float64,
                         σλc     ::Float64,
                         μc      ::Float64,
                         sns     ::NTuple{3,BitVector},
                         δt      ::Float64,
                         srδt    ::Float64,
                         inodes  ::Vector{Int64},
                         pup     ::Vector{Int64},
                         prints  ::Int64,
                         snodes! ::Function,
                         scond   ::Function,
                         scond0  ::Function)

  llc = llik_gbm(Ξ, idf, αc, σλc, μc, δt, srδt) + 
        scond(Ξ, μc, sns) + prob_ρ(idf)
  prc = logdinvgamma(σλc^2, σλ_prior[1], σλ_prior[2])        + 
        logdunif(exp(lλ(Ξ[1])[1]), λa_prior[1], λa_prior[2]) +
        logdnorm(αc, α_prior[1], α_prior[2]^2)               +
        logdgamma(μc, μ_prior[1], μ_prior[2])

  # maximum bounds according to unfiorm priors
  lλxpr = log(λa_prior[2])

  L       = treelength(Ξ)      # tree length
  dλ      = deltaλ(Ξ)          # delta change in λ
  ssλ, nλ = sss_gbm(Ξ, αc)     # sum squares in λ
  ne      = 0.0                # number of extinction events
  nin     = lastindex(inodes)  # number of internal nodes
  el      = lastindex(idf)     # number of branches

  pbar = Progress(nburn, prints, "burning mcmc...", 20)

  for i in Base.OneTo(nburn)

    shuffle!(pup)

    # parameter updates
    for pupi in pup

      # update drift
      if pupi === 1

        llc, prc, αc  = update_α!(αc, σλc, L, dλ, llc, prc, α_prior)

        # update ssλ with new drift `α`
        ssλ, nλ = sss_gbm(Ξ, αc)

      # update sigma
      elseif pupi === 2

        llc, prc, σλc = update_σ!(σλc, αc, ssλ, nλ, llc, prc, σλ_prior)

      # update extinction
      elseif pupi === 3

        llc, prc, μc = update_μ!(Ξ, llc, prc, μc, ne, L, sns, μ_prior, scond)

      # gbm update
      elseif pupi === 4

        nix = ceil(Int64,rand()*nin)
        bix = inodes[nix]

        llc, dλ, ssλ = 
          update_gbm!(bix, Ξ, idf, αc, σλc, μc, llc, dλ, ssλ, sns, δt, 
            srδt, lλxpr)

      # forward simulation update
      else

        bix = ceil(Int64,rand()*el)

        llc, dλ, ssλ, nλ, ne, L = 
          update_fs!(bix, Ξ, idf, αc, σλc, μc, llc, dλ, ssλ, nλ, ne, L, 
            sns, δt, srδt, snodes!, scond0)
      end
    end

    next!(pbar)
  end

  return Ξ, idf, llc, prc, αc, σλc, μc, sns
end







"""
    mcmc_gbmce(Ξ       ::Vector{iTgbmce},
               idf     ::Vector{iBffs},
               llc     ::Float64,
               prc     ::Float64,
               αc      ::Float64,
               σλc     ::Float64,
               μc      ::Float64,
               sns     ::NTuple{3,BitVector},
               λa_prior::NTuple{2,Float64},
               α_prior ::NTuple{2,Float64},
               σλ_prior::NTuple{2,Float64},
               μ_prior ::NTuple{2,Float64},
               niter   ::Int64,
               nthin   ::Int64,
               δt      ::Float64,
               srδt    ::Float64,
               inodes  ::Array{Int64,1},
               pup     ::Array{Int64,1},
               prints  ::Int64,
               snodes! ::Function,
               scond   ::Function,
               scond0  ::Function)

MCMC chain for `gbmce`.
"""
function mcmc_gbmce(Ξ       ::Vector{iTgbmce},
                    idf     ::Vector{iBffs},
                    llc     ::Float64,
                    prc     ::Float64,
                    αc      ::Float64,
                    σλc     ::Float64,
                    μc      ::Float64,
                    sns     ::NTuple{3,BitVector},
                    λa_prior::NTuple{2,Float64},
                    α_prior ::NTuple{2,Float64},
                    σλ_prior::NTuple{2,Float64},
                    μ_prior ::NTuple{2,Float64},
                    niter   ::Int64,
                    nthin   ::Int64,
                    δt      ::Float64,
                    srδt    ::Float64,
                    inodes  ::Array{Int64,1},
                    pup     ::Array{Int64,1},
                    prints  ::Int64,
                    snodes! ::Function,
                    scond   ::Function,
                    scond0  ::Function)

  # logging
  nlogs = fld(niter,nthin)
  lthin, lit = 0, 0

  # maximum bounds according to uniform priors
  lλxpr = log(λa_prior[2])

  L       = treelength(Ξ)            # tree length
  dλ      = deltaλ(Ξ)                # delta change in λ
  ssλ, nλ = sss_gbm(Ξ, αc)           # sum squares in λ
  ne      = Float64(ntipsextinct(Ξ)) # number of extinction events
  nin     = lastindex(inodes)        # number of internal nodes
  el      = lastindex(idf)           # number of branches

  # parameter results
  R = Array{Float64,2}(undef, nlogs, 7)

  # make Ξ vector
  Ξv = iTgbmce[]

  pbar = Progress(niter, prints, "running mcmc...", 20)

  for i in Base.OneTo(niter)

    shuffle!(pup)

    # parameter updates
    for pupi in pup

      # check for extinct

      # update σλ or σμ
      if pupi === 1

        llc, prc, αc  = update_α!(αc, σλc, L, dλ, llc, prc, α_prior)

        # update ssλ with new drift `α`
        ssλ, nλ = sss_gbm(Ξ, αc)

        # ll0 = llik_gbm(Ξ, idf, αc, σλc, μc, δt, srδt) + scond(Ξ, μc, sns) + prob_ρ(idf)
        # if !isapprox(ll0, llc, atol = 1e-5)
        #    @show ll0, llc, pupi, i, Ξ
        #    return 
        # end

      elseif pupi === 2

        llc, prc, σλc = update_σ!(σλc, αc, ssλ, nλ, llc, prc, σλ_prior)

        # ll0 = llik_gbm(Ξ, idf, αc, σλc, μc, δt, srδt) + scond(Ξ, μc, sns) + prob_ρ(idf)
        # if !isapprox(ll0, llc, atol = 1e-5)
        #    @show ll0, llc, pupi, i, Ξ
        #    return 
        # end

      elseif pupi === 3

        llc, prc, μc = update_μ!(Ξ, llc, prc, μc, ne, L, sns, μ_prior, scond)

        # ll0 = llik_gbm(Ξ, idf, αc, σλc, μc, δt, srδt) + scond(Ξ, μc, sns) + prob_ρ(idf)
        # if !isapprox(ll0, llc, atol = 1e-5)
        #    @show ll0, llc, pupi, i, Ξ
        #    return 
        # end

      # gbm update
      elseif pupi === 4

        nix = ceil(Int64,rand()*nin)
        bix = inodes[nix]

        llc, dλ, ssλ = 
          update_gbm!(bix, Ξ, idf, αc, σλc, μc, llc, dλ, ssλ, sns, δt, 
            srδt, lλxpr)

        # ll0 = llik_gbm(Ξ, idf, αc, σλc, μc, δt, srδt) + scond(Ξ, μc, sns) + prob_ρ(idf)
        # if !isapprox(ll0, llc, atol = 1e-5)
        #    @show ll0, llc, pupi, i, Ξ
        #    return 
        # end

      # forward simulation update
      else

        bix = ceil(Int64,rand()*el)

        llc, dλ, ssλ, nλ, ne, L = 
          update_fs!(bix, Ξ, idf, αc, σλc, μc, llc, dλ, ssλ, nλ, ne, L, 
            sns, δt, srδt, snodes!, scond0)

        # ll0 = llik_gbm(Ξ, idf, αc, σλc, μc, δt, srδt) + scond(Ξ, μc, sns) + prob_ρ(idf)
        # if !isapprox(ll0, llc, atol = 1e-5)
        #    @show ll0, llc, pupi, i, Ξ
        #    return 
        # end
      end
    end

    # log parameters
    lthin += 1
    if lthin === nthin
      lit += 1
      @inbounds begin
        R[lit,1] = Float64(lit)
        R[lit,2] = llc
        R[lit,3] = prc
        R[lit,4] = exp(lλ(Ξ[1])[1])
        R[lit,5] = αc
        R[lit,6] = σλc
        R[lit,7] = μc
        push!(Ξv, couple(deepcopy(Ξ), idf, 1))
      end
      lthin = 0
    end

    next!(pbar)
  end

  return R, Ξv
end




"""
    update_fs!(bix    ::Int64,
               Ξ      ::Vector{iTgbmce},
               idf    ::Vector{iBffs},
               α      ::Float64,
               σλ     ::Float64,
               μ      ::Float64,
               llc    ::Float64,
               dλ     ::Float64,
               ssλ    ::Float64,
               nλ     ::Float64,
               ne     ::Float64,
               L      ::Float64,
               sns    ::NTuple{3,BitVector},
               δt     ::Float64,
               srδt   ::Float64,
               snodes!::Function, 
               scond0 ::Function)

Forward simulation proposal function for `gbmce`.
"""
function update_fs!(bix    ::Int64,
                    Ξ      ::Vector{iTgbmce},
                    idf    ::Vector{iBffs},
                    α      ::Float64,
                    σλ     ::Float64,
                    μ      ::Float64,
                    llc    ::Float64,
                    dλ     ::Float64,
                    ssλ    ::Float64,
                    nλ     ::Float64,
                    ne     ::Float64,
                    L      ::Float64,
                    sns    ::NTuple{3,BitVector},
                    δt     ::Float64,
                    srδt   ::Float64,
                    snodes!::Function, 
                    scond0 ::Function)

  bi  = idf[bix]
  itb = it(bi) # if is terminal

  ξc  = Ξ[bix]
  if !itb
    ξ1  = Ξ[d1(bi)]
    ξ2  = Ξ[d2(bi)]
  end

  # forward simulate an internal branch
  ξp, np, ntp, λf = fsbi_ce(bi, lλ(ξc)[1], α, σλ, μ, δt, srδt)

  # check for survival or non-exploding simulation
  if np > 0

    ρbi = ρi(bi) # get branch sampling fraction
    nc  = ni(bi) # current ni
    ntc = nt(bi) # current nt

    # if terminal branch
    if itb
      llr  = log(Float64(np)/Float64(nc) * (1.0 - ρbi)^(np - nc))
      acr  = llr
      drλ  = 0.0
      ssrλ = 0.0
    else
      np -= 1
      llr = log((1.0 - ρbi)^(np - nc))
      acr = llr + log(Float64(ntp)/Float64(ntc))
      # change daughters
      if isfinite(acr)

        llrd, acrd, drλ, ssrλ, λ1p, λ2p = 
          _daughters_update!(ξ1, ξ2, λf, α, σλ, μ, δt, srδt)

        llr += llrd
        acr += acrd
      else
        return llc, dλ, ssλ, nλ, ne, L
      end
    end

    # MH ratio
    if -randexp() < acr

      ll1, dλ1, ssλ1, nλ1 = llik_gbm_ssλ(ξp, α, σλ, μ, δt, srδt)
      ll0, dλ0, ssλ0, nλ0 = llik_gbm_ssλ(ξc, α, σλ, μ, δt, srδt)

      # if stem or crown conditioned
      scn = (iszero(pa(bi)) && e(bi) > 0.0) || 
             (isone(pa(bi)) && iszero(e(Ξ[1])))
      if scn
        llr += scond0(ξp, μ, itb) - scond0(ξc, μ, itb)
      end

      # update llr, ssλ, nλ, sns, ne, L,
      llr += ll1  - ll0
      dλ  += dλ1  - dλ0  + drλ
      ssλ += ssλ1 - ssλ0 + ssrλ
      nλ  += nλ1  - nλ0
      ne  += ntipsextinct(ξp) - ntipsextinct(ξc)
      L   += treelength(ξp)   - treelength(ξc)

      Ξ[bix] = ξp          # set new tree
      llc += llr           # set new likelihood
      if scn
        snodes!(Ξ, sns)    # set new sns
      end
      setni!(bi, np)       # set new ni
      setnt!(bi, ntp)      # set new nt
      setλt!(bi, λf)       # set new λt
      if !itb
        copyto!(lλ(ξ1), λ1p) # set new daughter 1 λ vector
        copyto!(lλ(ξ2), λ2p) # set new daughter 2 λ vector
      end
    end
  end

  return llc, dλ, ssλ, nλ, ne, L
end




"""
    fsbi_ce(bi  ::iBffs,
            λ0  ::Float64,
            α   ::Float64,
            σλ  ::Float64,
            μ   ::Float64,
            δt  ::Float64,
            srδt::Float64)

Forward simulation for branch `bi`
"""
function fsbi_ce(bi  ::iBffs,
                 λ0  ::Float64,
                 α   ::Float64,
                 σλ  ::Float64,
                 μ   ::Float64,
                 δt  ::Float64,
                 srδt::Float64)

  # times
  tfb = tf(bi)

  # forward simulation during branch length
  t0, na, nsp = _sim_gbmce(e(bi), λ0, α, σλ, μ, δt, srδt, 0, 1, 1_000)

  if na < 1 || nsp >= 1_000
    return iTgbmce(), 0, 0, 0.0
  end

  nat = na

  if isone(na)
    f, λf = fixalive!(t0, NaN)

    return t0, na, nat, λf
  elseif na > 1
    # fix random tip
    λf = fixrtip!(t0, na, NaN)

    if !it(bi)
      # add tips until the present
      tx, na = tip_sims!(t0, tfb, α, σλ, μ, δt, srδt, na)
    end

    return t0, na, nat, λf
  end

  return iTgbmce(), 0, 0, 0.0
end




"""
    tip_sims!(tree::iTgbmce,
              t   ::Float64,
              α   ::Float64,
              σλ  ::Float64,
              μ   ::Float64,
              δt  ::Float64,
              srδt::Float64,
              na  ::Int64)

Continue simulation until time `t` for unfixed tips in `tree`. 
"""
function tip_sims!(tree::iTgbmce,
                   t   ::Float64,
                   α   ::Float64,
                   σλ  ::Float64,
                   μ   ::Float64,
                   δt  ::Float64,
                   srδt::Float64,
                   na  ::Int64)

  if istip(tree) 
    if !isfix(tree) && isalive(tree)

      fdti = fdt(tree)
      lλ0  = lλ(tree)

      # simulate
      stree, na, nsp = 
        _sim_gbmce(max(δt-fdti, 0.0), t, lλ0[end], α, σλ, μ, δt, srδt, 
                   na - 1, 1, 1_000)

      if !isdefined(stree, :lλ)
        return tree, 1_000
      end

      setproperty!(tree, :iμ, isextinct(stree))
      sete!(tree, e(tree) + e(stree))

      lλs = lλ(stree)

      if lastindex(lλs) === 2
        setfdt!(tree, fdt(tree) + fdt(stree))
      else
        setfdt!(tree, fdt(stree))
      end

      pop!(lλ0)
      popfirst!(lλs)
      append!(lλ0, lλs)

      if isdefined(stree, :d1)
        tree.d1 = stree.d1
        tree.d2 = stree.d2
      end
    end
  else
    tree.d1, na = tip_sims!(tree.d1, t, α, σλ, μ, δt, srδt, na)
    tree.d2, na = tip_sims!(tree.d2, t, α, σλ, μ, δt, srδt, na)
  end

  return tree, na
end





"""
    update_gbm!(bix  ::Int64,
                Ξ    ::Vector{iTgbmce},
                idf  ::Vector{iBffs},
                α    ::Float64,
                σλ   ::Float64,
                μ    ::Float64,
                llc  ::Float64,
                dλ   ::Float64,
                ssλ  ::Float64,
                sns  ::NTuple{3,BitVector},
                δt   ::Float64,
                srδt ::Float64,
                lλxpr::Float64)

Make a `gbm` update for an internal branch and its descendants.
"""
function update_gbm!(bix  ::Int64,
                     Ξ    ::Vector{iTgbmce},
                     idf  ::Vector{iBffs},
                     α    ::Float64,
                     σλ   ::Float64,
                     μ    ::Float64,
                     llc  ::Float64,
                     dλ   ::Float64,
                     ssλ  ::Float64,
                     sns  ::NTuple{3,BitVector},
                     δt   ::Float64,
                     srδt ::Float64,
                     lλxpr::Float64)

  @inbounds begin
    ξi   = Ξ[bix]
    bi   = idf[bix]
    ξ1   = Ξ[d1(bi)]
    ξ2   = Ξ[d2(bi)]
    ter1 = it(idf[d1(bi)]) 
    ter2 = it(idf[d2(bi)])

    cn = false
    # if crown root
    if iszero(pa(bi)) && iszero(e(bi))
      llc, dλ, ssλ = 
        _crown_update!(ξi, ξ1, ξ2, α, σλ, μ, llc, dλ, ssλ, δt, srδt, lλxpr)
      setλt!(bi, lλ(ξi)[1])

      # carry on updates in the crown daughter branches
      llc, dλ, ssλ = 
        _update_gbm!(ξ1, α, σλ, μ, llc, dλ, ssλ, δt, srδt, ter1, sns[2], 1)
      llc, dλ, ssλ = 
        _update_gbm!(ξ2, α, σλ, μ, llc, dλ, ssλ, δt, srδt, ter2, sns[3], 1)
    else
      # if stem branch
      if iszero(pa(bi))
        llc, dλ, ssλ = 
          _stem_update!(ξi, α, σλ, μ, llc, dλ, ssλ, δt, srδt, lλxpr)

        # updates within the stem branch in stem conditioning
        llc, dλ, ssλ = 
          _update_gbm!(ξi, α, σλ, μ, llc, dλ, ssλ, δt, srδt, false, sns[1], 1)

        # if observed node should be conditioned
        cn = sns[1][end]

      # if crown branch
      elseif isone(pa(bi)) && iszero(e(Ξ[1]))
        wsn = bix === d1(idf[pa(bi)]) ? 2 : 3
        sni = sns[wsn]
        # updates within the crown branch with crown conditioning
        llc, dλ, ssλ = 
          _update_gbm!(ξi, α, σλ, μ, llc, dλ, ssλ, δt, srδt, false, sni, 1)

        # if observed node should be conditioned
        if lastindex(sni) > 0
          cn = sni[end]
        end
      else
        # updates within the parent branch
        llc, dλ, ssλ = _update_gbm!(ξi, α, σλ, μ, llc, dλ, ssλ, δt, srδt, false)
      end

      # get fixed tip 
      lξi = fixtip(ξi) 

      # make between decoupled trees node update
      llc, dλ, ssλ = update_triad!(lλ(lξi), lλ(ξ1), lλ(ξ2), e(lξi), e(ξ1), e(ξ2), 
        fdt(lξi), fdt(ξ1), fdt(ξ2), α, σλ, μ, llc, dλ, ssλ, δt, srδt, cn)

      # set fixed `λ(t)` in branch
      setλt!(bi, lλ(lξi)[end])

      # carry on updates in the daughters
      llc, dλ, ssλ = _update_gbm!(ξ1, α, σλ, μ, llc, dλ, ssλ, δt, srδt, ter1)
      llc, dλ, ssλ = _update_gbm!(ξ2, α, σλ, μ, llc, dλ, ssλ, δt, srδt, ter2)
    end
  end

  return llc, dλ, ssλ
end






"""
    update_μ!(xi   ::Vector{iTgbmce},
              llc   ::Float64,
              prc   ::Float64,
              μc    ::Float64,
              ne    ::Float64,
              L     ::Float64,
              sns   ::NTuple{3,BitVector},
              μ_prior::NTuple{2,Float64},
              scond ::Function)

Gibbs-MH update for `μ`.
"""
function update_μ!(xi   ::Vector{iTgbmce},
                   llc   ::Float64,
                   prc   ::Float64,
                   μc    ::Float64,
                   ne    ::Float64,
                   L     ::Float64,
                   sns   ::NTuple{3,BitVector},
                   μ_prior::NTuple{2,Float64},
                   scond ::Function)

  μp  = randgamma(μ_prior[1] + ne, μ_prior[2] + L)
  llr = scond(xi, μp, sns) - scond(xi, μc, sns)

  if -randexp() < llr
    llc += ne*log(μp/μc) + L*(μc - μp) + llr
    prc += llrdgamma(μp, μc, μ_prior[1], μ_prior[2])
    μc   = μp
  end

  return llc, prc, μc
end




"""
    update_μ!(xi   ::Vector{iTgbmce},
              llc   ::Float64,
              prc   ::Float64,
              rdc   ::Float64,
              μc    ::Float64,
              μtn   ::Float64,
              ne    ::Float64,
              L     ::Float64,
              sns   ::NTuple{3,BitVector},
              μ_prior::Float64,
              μ_refd ::NTuple{2,Float64},
              scond ::Function,
              pow   ::Float64)

MCMC update for `μ`.
"""
function update_μ!(xi   ::Vector{iTgbmce},
                   llc   ::Float64,
                   prc   ::Float64,
                   rdc   ::Float64,
                   μc    ::Float64,
                   μtn   ::Float64,
                   ne    ::Float64,
                   L     ::Float64,
                   sns   ::NTuple{3,BitVector},
                   μ_prior::NTuple{2,Float64},
                   μ_refd ::NTuple{2,Float64},
                   scond ::Function,
                   pow   ::Float64)

  # parameter proposal
  μp = mulupt(μc, μtn)::Float64

  # log likelihood and prior ratio
  μr   = log(μp/μc)
  llr  = ne*μr + L*(μc - μp) + scond(xi, μp, sns) - scond(xi, μc, sns)
  prr = llrdgamma(μp, μc, μ_prior[1], μ_prior[2])
  rdr = llrdtnorm(μp, μc, μ_refd[1],  μ_refd[2])


  if -randexp() < (pow * (llr + prr) + (1.0 - pow) * rdr + μr)
    llc += llr
    prc += prr
    rdc += rdr
    μc   = μp
  end

  return llc, prc, rdc, μc
end

