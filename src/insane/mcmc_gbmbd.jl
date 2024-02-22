#=

Anagenetic `gbmbd` MCMC using forward simulation

Ignacio Quintero Mächler

t(-_-t)

Created 03 09 2020
=#




"""
    insane_gbmbd(tree    ::sT_label;
                 λa_prior::NTuple{2,Float64} = (0.0, 100.0),
                 μa_prior::NTuple{2,Float64} = (0.0, 100.0),
                 α_prior ::NTuple{2,Float64} = (0.0, 10.0),
                 σλ_prior::NTuple{2,Float64} = (3.0, 0.5),
                 σμ_prior::NTuple{2,Float64} = (3.0, 0.5),
                 niter   ::Int64             = 1_000,
                 nthin   ::Int64             = 10,
                 nburn   ::Int64             = 200,
                 nflush  ::Int64             = nthin,
                 ofile   ::String            = string(homedir(), "/ibd"),
                 ϵi      ::Float64           = 0.2,
                 λi      ::Float64           = NaN,
                 μi      ::Float64           = NaN,
                 αi      ::Float64           = 0.0,
                 σλi     ::Float64           = 0.01,
                 σμi     ::Float64           = 0.01,
                 pupdp   ::NTuple{4,Float64} = (0.01, 0.01, 0.1, 0.2),
                 δt      ::Float64           = 1e-3,
                 survival::Bool              = true,
                 mxthf   ::Float64           = Inf,
                 prints  ::Int64             = 5,
                 tρ      ::Dict{String, Float64} = Dict("" => 1.0))

Run insane for `bdd`.
"""
function insane_gbmbd(tree    ::sT_label;
                      λa_prior::NTuple{2,Float64}     = (0.0, 100.0),
                      μa_prior::NTuple{2,Float64}     = (0.0, 100.0),
                      α_prior ::NTuple{2,Float64}     = (0.0, 10.0),
                      σλ_prior::NTuple{2,Float64}     = (3.0, 0.5),
                      σμ_prior::NTuple{2,Float64}     = (3.0, 0.5),
                      niter   ::Int64                 = 1_000,
                      nthin   ::Int64                 = 10,
                      nburn   ::Int64                 = 200,
                      nflush  ::Int64                 = nthin,
                      ofile   ::String                = string(homedir(), "/ibd"),
                      ϵi      ::Float64               = 0.2,
                      λi      ::Float64               = NaN,
                      μi      ::Float64               = NaN,
                      αi      ::Float64               = 0.0,
                      σλi     ::Float64               = 0.01,
                      σμi     ::Float64               = 0.01,
                      pupdp   ::NTuple{5,Float64}     = (0.01, 0.01, 0.1, 0.1, 0.2),
                      δt      ::Float64               = 1e-3,
                      survival::Bool                  = true,
                      mxthf   ::Float64               = Inf,
                      prints  ::Int64                 = 5,
                      stnλ    ::Float64               = 0.5,
                      stnμ    ::Float64               = 0.5,
                      tρ      ::Dict{String, Float64} = Dict("" => 1.0))

  # `n` tips, `th` treeheight define δt
  n     = ntips(tree)
  th    = treeheight(tree)
  δt   *= max(0.1,round(th, RoundDown, digits = 2))
  srδt  = sqrt(δt)
  surv  = survival ? 1 + Int64(iszero(e(tree))) : 0

  # set tips sampling fraction
  if isone(length(tρ))
    tl = tiplabels(tree)
    tρu = tρ[""]
    tρ = Dict(tl[i] => tρu for i in 1:n)
  end

  # estimate branch split (multiple of δt)
  ndts = floor(th * mxthf/δt)
  maxt = δt * ndts

  # make fix tree directory
  idf = make_idf(tree, tρ, maxt)

   # starting parameters (using method of moments)
  if isnan(λi) || isnan(μi)
    λc, μc = moments(Float64(n), th, ϵi)
  else
    λc, μc = λi, μi
  end

  # make a decoupled tree
  Ξ = make_Ξ(idf, λc, μc, αi, σλi, σμi, δt, srδt, iTbd)

  # survival
  mc = m_surv_gbmbd(th, log(λc), log(μc), αi, σλi, σμi, δt, srδt, 1_000, surv)

  # get vector of internal branches
  inodes = [i for i in Base.OneTo(lastindex(idf))  if d1(idf[i]) > 0]

  # parameter updates (1: α, 2: σλ, 3: σμ, 4: gbm, 5: forward simulation)
  spup = sum(pupdp)
  pup  = Int64[]
  for i in Base.OneTo(lastindex(pupdp))
    append!(pup, fill(i, ceil(Int64, Float64(2*n - 1) * pupdp[i]/spup)))
  end

  @info "running birth-death gbm"

  # burn-in phase
  Ξ, idf, llc, prc, αc, σλc, σμc, mc, stnλ, stnμ =
    mcmc_burn_gbmbd(Ξ, idf, λa_prior, μa_prior, α_prior, σλ_prior, σμ_prior,
      nburn, αi, σλi, σμi, mc, th, surv, stnλ, stnμ, δt, srδt, inodes, pup, 
      prints)

  # mcmc
  r, treev =
    mcmc_gbmbd(Ξ, idf, llc, prc, αc, σλc, σμc, mc, th, surv, stnλ, stnμ,
      λa_prior, μa_prior, α_prior, σλ_prior, σμ_prior, δt, srδt, inodes, pup, 
      niter, nthin, nflush, ofile, prints)

  return r, treev
end




"""
    mcmc_burn_gbmbd(Ξ       ::Vector{iTbd},
                    idf     ::Vector{iBffs},
                    λa_prior::NTuple{2,Float64},
                    μa_prior::NTuple{2,Float64},
                    α_prior ::NTuple{2,Float64},
                    σλ_prior::NTuple{2,Float64},
                    σμ_prior::NTuple{2,Float64},
                    nburn   ::Int64,
                    αc      ::Float64,
                    σλc     ::Float64,
                    σμc     ::Float64,
                    mc      ::Float64,
                    th      ::Float64,
                    surv    ::Int64,
                    stnλ    ::Float64, 
                    stnμ    ::Float64,
                    δt      ::Float64,
                    srδt    ::Float64,
                    inodes  ::Array{Int64,1},
                    pup     ::Array{Int64,1},
                    prints  ::Int64)

MCMC burn-in chain for `bdd`.
"""
function mcmc_burn_gbmbd(Ξ       ::Vector{iTbd},
                         idf     ::Vector{iBffs},
                         λa_prior::NTuple{2,Float64},
                         μa_prior::NTuple{2,Float64},
                         α_prior ::NTuple{2,Float64},
                         σλ_prior::NTuple{2,Float64},
                         σμ_prior::NTuple{2,Float64},
                         nburn   ::Int64,
                         αc      ::Float64,
                         σλc     ::Float64,
                         σμc     ::Float64,
                         mc      ::Float64,
                         th      ::Float64,
                         surv    ::Int64,
                         stnλ    ::Float64, 
                         stnμ    ::Float64,
                         δt      ::Float64,
                         srδt    ::Float64,
                         inodes  ::Array{Int64,1},
                         pup     ::Array{Int64,1},
                         prints  ::Int64)

  λ0  = lλ(Ξ[1])[1]
  nsi = Float64(surv > 0)
  llc = llik_gbm(Ξ, idf, αc, σλc, σμc, δt, srδt) - nsi * λ0 +
        log(mc) + prob_ρ(idf)
  prc = logdinvgamma(σλc^2,        σλ_prior[1], σλ_prior[2])  +
        logdinvgamma(σμc^2,        σμ_prior[1], σμ_prior[2])  +
        logdnorm(αc,               α_prior[1],  α_prior[2]^2) +
        logdunif(exp(λ0),          λa_prior[1], λa_prior[2])  +
        logdunif(exp(lμ(Ξ[1])[1]), μa_prior[1], μa_prior[2])

  lλxpr = log(λa_prior[2])
  lμxpr = log(μa_prior[2])

  L   = treelength(Ξ)        # tree length
  nin = lastindex(inodes)   # number of internal nodes
  el  = lastindex(idf)      # number of branches
  ns  = Float64(nin) - nsi  # number of speciation events in likelihood
  ne  = 0.0                 # number of extinction events in likelihood

  # delta change, sum squares, path length and integrated rate
  ddλ, ssλ, ssμ, nλ, irλ, irμ = _ss_ir_dd(Ξ, αc)

  pbar = Progress(nburn, prints, "burning mcmc...", 20)

  # for scale tuning
  ltn = 0
  lup = lacλ = lacμ = 0.0

  for i in Base.OneTo(nburn)

    shuffle!(pup)

    # parameter updates
    for pupi in pup

      # update α
      if pupi === 1

        llc, prc, αc, mc  =
          update_α!(αc, lλ(Ξ[1])[1], lμ(Ξ[1])[1], σλc, σμc, L, ddλ, llc, prc,
            mc, th, surv, δt, srδt, α_prior)

        # update ssλ, ssμ with new drift `α`
        ssλ, ssμ = _ss(Ξ, αc)

      # σλ & σμ update
      elseif pupi === 2

        llc, prc, σλc, σμc, mc =
          update_σ!(σλc, σμc, lλ(Ξ[1])[1], lμ(Ξ[1])[1], αc, ssλ, ssμ, nλ,
            llc, prc, mc, th, surv, δt, srδt, σλ_prior, σμ_prior)

      # update scale
      elseif pupi === 4

        llc, irλ, irμ, accλ, accμ, mc = 
          update_scale!(Ξ, idf, αc, σλc, σμc, llc, irλ, irμ, ns, ne, 
            stnλ, stnμ, mc, th, surv, δt, srδt)

        lacλ += accλ
        lacμ += accμ
        lup += 1.0

      # gbm update
      elseif pupi === 4

        nix = ceil(Int64,rand()*nin)
        bix = inodes[nix]

        llc, ddλ, ssλ, ssμ, irλ, irμ, mc =
          update_gbm!(bix, Ξ, idf, αc, σλc, σμc, llc, ddλ, ssλ, ssμ, irλ, irμ,
            mc, th, δt, srδt, lλxpr, lμxpr, surv)


      # forward simulation update
      else

        bix = ceil(Int64,rand()*el)

        llc, ddλ, ssλ, ssμ, nλ, irλ, irμ, ns, ne, L =
          update_fs!(bix, Ξ, idf, αc, σλc, σμc, llc, ddλ, ssλ, ssμ, nλ, 
            irλ, irμ, ns, ne, L, δt, srδt)
      end
    end

    next!(pbar)
  end

  return Ξ, idf, llc, prc, αc, σλc, σμc, mc
end




"""
    mcmc_gbmbd(Ξ       ::Vector{iTbd},
               idf     ::Vector{iBffs},
               llc     ::Float64,
               prc     ::Float64,
               αc      ::Float64,
               σλc     ::Float64,
               σμc     ::Float64,
               mc      ::Float64,
               th      ::Float64,
               surv    ::Int64,
               stnλ    ::Float64, 
               stnμ    ::Float64,
               λa_prior::NTuple{2,Float64},
               μa_prior::NTuple{2,Float64},
               α_prior ::NTuple{2,Float64},
               σλ_prior::NTuple{2,Float64},
               σμ_prior::NTuple{2,Float64},
               δt      ::Float64,
               srδt    ::Float64,
               inodes  ::Array{Int64,1},
               pup     ::Vector{Int64},
               niter   ::Int64,
               nthin   ::Int64,
               nflush  ::Int64,
               ofile   ::String,
               prints  ::Int64)

MCMC chain for `bdd`.
"""
function mcmc_gbmbd(Ξ       ::Vector{iTbd},
                    idf     ::Vector{iBffs},
                    llc     ::Float64,
                    prc     ::Float64,
                    αc      ::Float64,
                    σλc     ::Float64,
                    σμc     ::Float64,
                    mc      ::Float64,
                    th      ::Float64,
                    surv    ::Int64,
                    stnλ    ::Float64, 
                    stnμ    ::Float64,
                    λa_prior::NTuple{2,Float64},
                    μa_prior::NTuple{2,Float64},
                    α_prior ::NTuple{2,Float64},
                    σλ_prior::NTuple{2,Float64},
                    σμ_prior::NTuple{2,Float64},
                    δt      ::Float64,
                    srδt    ::Float64,
                    inodes  ::Array{Int64,1},
                    pup     ::Vector{Int64},
                    niter   ::Int64,
                    nthin   ::Int64,
                    nflush  ::Int64,
                    ofile   ::String,
                    prints  ::Int64)

  # logging
  nlogs = fld(niter,nthin)
  lthin, lit = 0, 0

  lλxpr = log(λa_prior[2])
  lμxpr = log(μa_prior[2])

  L            = treelength(Ξ)     # tree length
  ddλ          = deltaλ(Ξ)         # delta change in λ
  ssλ, ssμ, nλ = sss_gbm(Ξ, αc)    # sum squares in λ and μ
  nin          = lastindex(inodes) # number of internal nodes
  el           = lastindex(idf)    # number of branches

  # parameter results
  r = Array{Float64,2}(undef, nlogs, 8)

  # make Ξ vector
  treev = iTbd[]

  # number of branches and of triads
  nbr  = lastindex(idf)

  # flush to file
  sthin = 0

  open(ofile*".log", "w") do of

    write(of, "iteration\tlikelihood\tprior\tlambda_root\tmu_root\talpha\tsigma_lambda\tsigma_mu\n")
    flush(of)

    open(ofile*".txt", "w") do tf

      pbar = Progress(niter, prints, "running mcmc...", 20)

      for it in Base.OneTo(niter)

        shuffle!(pup)

        # parameter updates
        for pupi in pup

          # update α
          if pupi === 1

            llc, prc, αc, mc  =
              update_α!(αc, lλ(Ξ[1])[1], lμ(Ξ[1])[1], σλc, σμc, L, ddλ, llc, prc,
                mc, th, surv, δt, srδt, α_prior) 

            # update ssλ with new drift `α`
            ssλ, ssμ, nλ = sss_gbm(Ξ, αc)

            # ll0 = llik_gbm(Ξ, idf, αc, σλc, σμc, δt, srδt) - Float64(surv > 0) * lλ(Ξ[1])[1] + log(mc) + prob_ρ(idf)
            #  if !isapprox(ll0, llc, atol = 1e-4) || !isapprox(ddλ, deltaλ(Ξ))
            #    @show ll0, llc, i, pupi, Ξ
            #    return
            # end

          # σλ & σμ update
          elseif pupi === 2

            llc, prc, σλc, σμc, mc =
              update_σ!(σλc, σμc, lλ(Ξ[1])[1], lμ(Ξ[1])[1], αc, ssλ, ssμ, nλ,
                llc, prc, mc, th, surv, δt, srδt, σλ_prior, σμ_prior)

            # ll0 = llik_gbm(Ξ, idf, αc, σλc, σμc, δt, srδt) - Float64(surv > 0) * lλ(Ξ[1])[1] + log(mc) + prob_ρ(idf)
            #  if !isapprox(ll0, llc, atol = 1e-4) || !isapprox(ddλ, deltaλ(Ξ))
            #    @show ll0, llc, i, pupi, Ξ
            #    return
            # end

          # gbm update
          elseif pupi === 3

            nix = ceil(Int64,rand()*nin)
            bix = inodes[nix]

            llc, ddλ, ssλ, ssμ, mc =
              update_gbm!(bix, Ξ, idf, αc, σλc, σμc, llc, ddλ, ssλ, ssμ, mc, th,
                δt, srδt, lλxpr, lμxpr)

            # ll0 = llik_gbm(Ξ, idf, αc, σλc, σμc, δt, srδt) - Float64(surv > 0) * lλ(Ξ[1])[1] + log(mc) + prob_ρ(idf)
            #  if !isapprox(ll0, llc, atol = 1e-4) || !isapprox(ddλ, deltaλ(Ξ))
            #    @show ll0, llc, i, pupi, Ξ
            #    return
            # end

          # forward simulation update
          else

            bix = ceil(Int64,rand()*el)

            llc, ddλ, ssλ, ssμ, nλ, L =
              update_fs!(bix, Ξ, idf, αc, σλc, σμc, llc, ddλ, ssλ, ssμ, nλ, L,
                δt, srδt)

            # ll0 = llik_gbm(Ξ, idf, αc, σλc, σμc, δt, srδt) - Float64(surv > 0) * lλ(Ξ[1])[1] + log(mc) + prob_ρ(idf)
            #  if !isapprox(ll0, llc, atol = 1e-4) || !isapprox(ddλ, deltaλ(Ξ))
            #    @show ll0, llc, i, pupi, Ξ
            #    return
            # end
          end
        end

        # log parameters
        lthin += 1
        if lthin === nthin
          lit += 1
          @inbounds begin
            r[lit,1] = Float64(it)
            r[lit,2] = llc
            r[lit,3] = prc
            r[lit,4] = exp(lλ(Ξ[1])[1])
            r[lit,5] = exp(lμ(Ξ[1])[1])
            r[lit,6] = αc
            r[lit,7] = σλc
            r[lit,8] = σμc
            push!(treev, couple(Ξ, idf, 1))
          end
          lthin = 0
        end

        # flush parameters
        sthin += 1
        if sthin === nflush
          write(of, 
            string(Float64(it), "\t", llc, "\t", prc, "\t", 
              exp(lλ(Ξ[1])[1]),"\t", exp(lμ(Ξ[1])[1]), "\t", αc, "\t",
               σλc, "\t", σμc,"\n"))
          flush(of)
          write(tf, 
            string(istring(couple(Ξ, idf, 1)), "\n"))
          flush(tf)
          sthin = 0
        end

        next!(pbar)
      end
    end
  end

  return r, treev
end




"""
    update_α!(αc     ::Float64,
              λ0     ::Float64,
              μ0     ::Float64,
              σλ     ::Float64,
              σμ     ::Float64,
              L      ::Float64,
              ddλ     ::Float64,
              llc    ::Float64,
              prc    ::Float64,
              mc     ::Float64,
              th     ::Float64,
              surv   ::Int64,
              δt     ::Float64,
              srδt   ::Float64,
              α_prior::NTuple{2,Float64})

Gibbs update for `α`.
"""
function update_α!(αc     ::Float64,
                   λ0     ::Float64,
                   μ0     ::Float64,
                   σλ     ::Float64,
                   σμ     ::Float64,
                   L      ::Float64,
                   ddλ     ::Float64,
                   llc    ::Float64,
                   prc    ::Float64,
                   mc     ::Float64,
                   th     ::Float64,
                   surv   ::Int64,
                   δt     ::Float64,
                   srδt   ::Float64,
                   α_prior::NTuple{2,Float64})

  ν   = α_prior[1]
  τ2  = α_prior[2]^2
  σλ2 = σλ^2
  rs  = σλ2/τ2
  αp  = rnorm((ddλ + rs*ν)/(rs + L), sqrt(σλ2/(rs + L)))

  mp  = m_surv_gbmbd(th, λ0, μ0, αp, σλ, σμ, δt, srδt, 1_000, surv)
  llr = log(mp/mc)

  if -randexp() < llr
    llc += 0.5*L/σλ2*(αc^2 - αp^2 + 2.0*ddλ*(αp - αc)/L) + llr
    prc += llrdnorm_x(αp, αc, ν, τ2)
    αc   = αp
    mc   = mp
  end

  return llc, prc, αc, mc
end




"""
    update_σ!(σλc     ::Float64,
              σμc     ::Float64,
              λ0      ::Float64,
              μ0      ::Float64,
              α       ::Float64,
              ssλ     ::Float64,
              ssμ     ::Float64,
              n       ::Float64,
              llc     ::Float64,
              prc     ::Float64,
              mc      ::Float64,
              th      ::Float64,
              surv    ::Bool,
              δt      ::Float64,
              srδt    ::Float64,
              σλ_prior::NTuple{2,Float64},
              σμ_prior::NTuple{2,Float64})

Gibbs update for `σλ` and `σμ`.
"""
function update_σ!(σλc     ::Float64,
                   σμc     ::Float64,
                   λ0      ::Float64,
                   μ0      ::Float64,
                   α       ::Float64,
                   ssλ     ::Float64,
                   ssμ     ::Float64,
                   n       ::Float64,
                   llc     ::Float64,
                   prc     ::Float64,
                   mc      ::Float64,
                   th      ::Float64,
                   surv    ::Int64,
                   δt      ::Float64,
                   srδt    ::Float64,
                   σλ_prior::NTuple{2,Float64},
                   σμ_prior::NTuple{2,Float64})

  # Gibbs update for σ
  σλp2 = randinvgamma(σλ_prior[1] + 0.5 * n, σλ_prior[2] + ssλ)
  σμp2 = randinvgamma(σμ_prior[1] + 0.5 * n, σμ_prior[2] + ssμ)

  σλp = sqrt(σλp2)
  σμp = sqrt(σμp2)

  mp  = m_surv_gbmbd(th, λ0, μ0, α, σλp, σμp, δt, srδt, 1_000, surv)

  llr = log(mp/mc)

  if -randexp() < llr
    llc += ssλ*(1.0/σλc^2 - 1.0/σλp2) - n*(log(σλp/σλc)) +
           ssμ*(1.0/σμc^2 - 1.0/σμp2) - n*(log(σμp/σμc)) +
           llr
    prc += llrdinvgamma(σλp2, σλc^2, σλ_prior[1], σλ_prior[2]) +
           llrdinvgamma(σμp2, σμc^2, σμ_prior[1], σμ_prior[2])
    σλc  = σλp
    σμc  = σμp
    mc   = mp
  end

  return llc, prc, σλc, σμc, mc
end




"""
    update_scale!(Ξ   ::Vector{T},
                  idf ::Vector{iBffs},
                  α    ::Float64,
                  σλ   ::Float64,
                  σμ   ::Float64,
                  llc ::Float64,
                  irλ ::Float64,
                  irμ ::Float64,
                  ns  ::Float64,
                  ne  ::Float64,
                  stnλ::Float64,
                  stnμ::Float64,
                  mc  ::Float64,
                  th  ::Float64,
                  surv::Int64,
                  δt  ::Float64,
                  srδt::Float64) where {T <: iTbdU}

Update scale for speciation.
"""
function update_scale!(Ξ   ::Vector{T},
                       idf ::Vector{iBffs},
                       α    ::Float64,
                       σλ   ::Float64,
                       σμ   ::Float64,
                       llc ::Float64,
                       irλ ::Float64,
                       irμ ::Float64,
                       ns  ::Float64,
                       ne  ::Float64,
                       stnλ::Float64,
                       stnμ::Float64,
                       mc  ::Float64,
                       th  ::Float64,
                       surv::Int64,
                       δt  ::Float64,
                       srδt::Float64) where {T <: iTbdU}
  accλ = accμ = 0.0

  # sample log(scaling factor)
  s = randn()*stnλ

  # likelihood ratio
  mp = m_surv_gbmbd(th, lλ(Ξ[1])[1] + s, lμ(Ξ[1])[1], 
         α, σλ, σμ, δt, srδt, 1_000, surv)
  iri = (1.0 - exp(s)) * irλ
  llr = ns * s + iri + log(mp/mc)

  if -randexp() < llr
    accλ += 1.0
    llc  += llr
    irλ  -= iri
    mc    = mp
    scale_rate!(Ξ, lλ, s)
    scale_rate!(idf, s)
  end

  # sample log(scaling factor)
  s = randn()*stnμ

  # likelihood ratio
  mp = m_surv_gbmbd(th, lλ(Ξ[1])[1], lμ(Ξ[1])[1] + s, 
        α, σλ, σμ, δt, srδt, 1_000, surv)
  iri = (1.0 - exp(s)) * irμ
  llr = ne * s + iri + log(mp/mc)

  if -randexp() < llr
    accμ += 1.0
    llc  += llr
    irμ  -= iri
    mc   = mp
    scale_rate!(Ξ, lμ, s)
  end

  return llc, irλ, irμ, accλ, accμ, mc
end




"""
    update_gbm!(bix  ::Int64,
                Ξ    ::Vector{T},
                idf  ::Vector{iBffs},
                α    ::Float64,
                σλ   ::Float64,
                σμ   ::Float64,
                llc  ::Float64,
                ddλ   ::Float64,
                ssλ  ::Float64,
                ssμ  ::Float64,
                mc   ::Float64,
                th   ::Float64,
                crown::Int64
                δt   ::Float64,
                srδt ::Float64,
                lλxpr::Float64,
                lμxpr::Float64,
                surv ::Int64)

Make a `gbm` update for an internal branch and its descendants.
"""
function update_gbm!(bix  ::Int64,
                     Ξ    ::Vector{T},
                     idf  ::Vector{iBffs},
                     α    ::Float64,
                     σλ   ::Float64,
                     σμ   ::Float64,
                     llc  ::Float64,
                     ddλ  ::Float64,
                     ssλ  ::Float64,
                     ssμ  ::Float64,
                     irλ  ::Float64, 
                     irμ  ::Float64,
                     mc   ::Float64,
                     th   ::Float64,
                     δt   ::Float64,
                     srδt ::Float64,
                     lλxpr::Float64,
                     lμxpr::Float64,
                     surv ::Int64) where {T <: iTbdU}
  @inbounds begin

    ξi   = Ξ[bix]
    bi   = idf[bix]
    i1   = d1(bi)
    i2   = d2(bi)
    ξ1   = Ξ[i1]
    root = iszero(pa(bi))

    # if crown
    if root && iszero(e(bi))
      llc, ddλ, ssλ, ssμ, irλ, irμ, mc =
        _crown_update!(ξi, ξ1, Ξ[i2], α, σλ, σμ, llc, ddλ, ssλ, ssμ, irλ, irμ, 
          mc, th, δt, srδt, lλxpr, lμxpr, surv)
      setλt!(bi, lλ(ξi)[1])
    else
      # if stem
      if root
        llc, ddλ, ssλ, ssμ, irλ, irμ, mc =
          _stem_update!(ξi, α, σλ, σμ, llc, ddλ, ssλ, ssμ, irλ, irμ,
            mc, th, δt, srδt, lλxpr, lμxpr, surv)
      end

      # updates within the parent branch
      llc, ddλ, ssλ, ssμ, irλ, irμ =
        _update_gbm!(ξi, α, σλ, σμ, llc, ddλ, ssλ, ssμ, irλ, irμ, 
          δt, srδt, false)

      # get fixed tip
      lξi = fixtip(ξi)

      # if mid branch
      if iszero(i2)

        llc, ssλ, ssμ, irλ, irμ =
          update_duo!(lλ(lξi), lλ(ξ1), lμ(lξi), lμ(ξ1), e(lξi), e(ξ1),
            fdt(lξi), fdt(ξ1), α, σλ, σμ, llc, ssλ, ssμ, irλ, irμ, δt, srδt)

      # if internal branch
      else
        ξ2 = Ξ[i2]
        # make between decoupled trees node update
        llc, ddλ, ssλ, ssμ, irλ, irμ, λf =
          update_triad!(lλ(lξi), lλ(ξ1), lλ(ξ2), lμ(lξi), lμ(ξ1), lμ(ξ2),
            e(lξi), e(ξ1), e(ξ2), fdt(lξi), fdt(ξ1), fdt(ξ2),
            α, σλ, σμ, llc, ddλ, ssλ, ssμ, irλ, irμ, δt, srδt)

        # set fixed `λ(t)` in branch
        setλt!(bi, λf)
      end
    end

    # carry on updates in the daughters
    llc, ddλ, ssλ, ssμ, irλ, irμ =
      _update_gbm!(ξ1, α, σλ, σμ, llc, ddλ, ssλ, ssμ, irλ, irμ, δt, srδt,
        iszero(d1(idf[i1])))

    if i2 > 0
      llc, ddλ, ssλ, ssμ, irλ, irμ =
        _update_gbm!(Ξ[i2], α, σλ, σμ, llc, ddλ, ssλ, ssμ, irλ, irμ, δt, srδt, 
          iszero(d1(idf[i2])))
    end
  end

  return llc, ddλ, ssλ, ssμ, irλ, irμ, mc
end




"""
    update_fs!(bix ::Int64,
               Ξ   ::Vector{iTbd},
               idf ::Vector{iBffs},
               α   ::Float64,
               σλ  ::Float64,
               σμ  ::Float64,
               llc ::Float64,
               ddλ ::Float64,
               ssλ ::Float64,
               ssμ ::Float64,
               nλ  ::Float64,
               irλ ::Float64,
               irμ ::Float64,
               ns  ::Float64,
               ne  ::Float64,
               L   ::Float64,
               δt  ::Float64,
               srδt::Float64)

Forward simulation proposal function for `bdd`.
"""
function update_fs!(bix ::Int64,
                    Ξ   ::Vector{iTbd},
                    idf ::Vector{iBffs},
                    α   ::Float64,
                    σλ  ::Float64,
                    σμ  ::Float64,
                    llc ::Float64,
                    ddλ ::Float64,
                    ssλ ::Float64,
                    ssμ ::Float64,
                    nλ  ::Float64,
                    irλ ::Float64,
                    irμ ::Float64,
                    ns  ::Float64,
                    ne  ::Float64,
                    L   ::Float64,
                    δt  ::Float64,
                    srδt::Float64)

  bi = idf[bix]
  ξc = Ξ[bix]

  # if terminal
  if iszero(d1(bi))
    ξp, llr = fsbi_t(bi, ξc, α, σλ, σμ, δt, srδt)
    drλ = ssrλ = ssrμ  = irrλ = irrμ = 0.0

  # if mid
  elseif iszero(d2(bi))
    ξp, llr, drλ, ssrλ, ssrμ, irrλ, irrμ =
      fsbi_m(bi, ξc, Ξ[d1(bi)], α, σλ, σμ, δt, srδt)

  # if internal
  else
    ξp, llr, drλ, ssrλ, ssrμ, irrλ, irrμ =
      fsbi_i(bi, ξc, Ξ[d1(bi)], Ξ[d2(bi)], α, σλ, σμ, δt, srδt)
  end

  # if accepted
  if isfinite(llr)
    ll1, ddλ1, ssλ1, ssμ1, nλ1, irλ1, irμ1, ns1, ne1 = 
      llik_gbm_ss(ξp, α, σλ, σμ, δt, srδt, 0.0, 0.0)
    ll0, ddλ0, ssλ0, ssμ0, nλ0, irλ0, irμ0, ns0, ne0 = 
      llik_gbm_ss(ξc, α, σλ, σμ, δt, srδt, 0.0, 0.0)

    # update quantities
    llc += ll1  - ll0  + llr
    ddλ += ddλ1 - ddλ0 + drλ
    ssλ += ssλ1 - ssλ0 + ssrλ
    ssμ += ssμ1 - ssμ0 + ssrμ
    nλ  += nλ1  - nλ0
    irλ += irλ1 - irλ0 + irrλ
    irμ += irμ1 - irμ0 + irrμ
    ns  += ns1  - ns0
    ne  += ne1  - ne0
    L   += treelength(ξp) - treelength(ξc)

    # set new tree
    Ξ[bix] = ξp
  end

  return llc, ddλ, ssλ, ssμ, nλ, irλ, irμ, ns, ne, L
end




"""
    fsbi_t(bi  ::iBffs,
           ξc  ::iTbd,
           α   ::Float64,
           σλ  ::Float64,
           σμ  ::Float64,
           δt  ::Float64,
           srδt::Float64)

Forward simulation for terminal branch `bi`.
"""
function fsbi_t(bi  ::iBffs,
                ξc  ::iTbd,
                α   ::Float64,
                σλ  ::Float64,
                σμ  ::Float64,
                δt  ::Float64,
                srδt::Float64)

  nac = ni(bi)         # current ni
  Iρi = (1.0 - ρi(bi)) # inv branch sampling fraction
  lU  = -randexp()     # log-probability

  # current ll
  lc = - log(Float64(nac)) - Float64(nac - 1) * (iszero(Iρi) ? 0.0 : log(Iρi))

  # forward simulation during branch length
  t0, na, nn, llr =
    _sim_gbmbd_t(e(bi), lλ(ξc)[1], lμ(ξc)[1], α, σλ, σμ, δt, srδt, 
      lc, lU, Iρi, 0, 1, 1_000)

  if na > 0 && isfinite(llr)
    _fixrtip!(t0, na) # fix random tip
    setni!(bi, na)    # set new ni

    return t0, llr
  else
    return t0, -Inf
  end
end




"""
    fsbi_m(bi  ::iBffs,
           ξc  ::iTbd,
           ξ1  ::iTbd,
           ξ2  ::iTbd,
           λ0  ::Float64,
           α   ::Float64,
           σλ  ::Float64,
           μ   ::Float64,
           δt  ::Float64,
           srδt::Float64)

Forward simulation for branch `bi`
"""
function fsbi_m(bi  ::iBffs,
                ξc  ::iTbd,
                ξ1  ::iTbd,
                α   ::Float64,
                σλ  ::Float64,
                σμ  ::Float64,
                δt  ::Float64,
                srδt::Float64)

  t0, na, nn =
    _sim_gbmbd(e(bi), lλ(ξc)[1], lμ(ξc)[1], α, σλ, σμ, δt, srδt, 0, 1, 1_000)

  if na < 1 || nn > 999
    return t0, NaN, NaN, NaN, NaN, NaN, NaN
  end

  ntp = na

  lU = -randexp() #log-probability

  # continue simulation only if acr on sum of tip rates is accepted
  acr  = log(Float64(ntp)/Float64(nt(bi)))
  nac  = ni(bi)                # current ni
  Iρi  = (1.0 - ρi(bi))        # branch sampling fraction
  acr -= Float64(nac) * (iszero(Iρi) ? 0.0 : log(Iρi))

  # sample and fix random  tip
  λf, μf = fixrtip!(t0, na, NaN, NaN) # fix random tip

  llrd, acrd, drλ, ssrλ, ssrμ, irrλ, irrμ, λ1p, μ1p =
    _daughter_update!(ξ1, λf, μf, α, σλ, σμ, δt, srδt)

  acr += acrd

  if lU < acr

    # simulate remaining tips until the present
    if na > 1
      tx, na, nn, acr =
        tip_sims!(t0, tf(bi), α, σλ, σμ, δt, srδt, acr, lU, Iρi, na, nn)
    end

    if lU < acr
      na -= 1

      llr = llrd + (na - nac)*(iszero(Iρi) ? 0.0 : log(Iρi))
      l1  = lastindex(λ1p)
      setnt!(bi, ntp)                       # set new nt
      setni!(bi, na)                        # set new ni
      unsafe_copyto!(lλ(ξ1), 1, λ1p, 1, l1) # set new daughter 1 λ vector
      unsafe_copyto!(lμ(ξ1), 1, μ1p, 1, l1) # set new daughter 1 μ vector

      return t0, llr, drλ, ssrλ, ssrμ, irrλ, irrμ
    end
  end

  return t0, NaN, NaN, NaN, NaN, NaN, NaN
end




"""
    fsbi_i(bi  ::iBffs,
           ξc  ::iTbd,
           ξ1  ::iTbd,
           ξ2  ::iTbd,
           λ0  ::Float64,
           α   ::Float64,
           σλ  ::Float64,
           μ   ::Float64,
           δt  ::Float64,
           srδt::Float64)

Forward simulation for branch `bi`
"""
function fsbi_i(bi  ::iBffs,
                ξc  ::iTbd,
                ξ1  ::iTbd,
                ξ2  ::iTbd,
                α   ::Float64,
                σλ  ::Float64,
                σμ  ::Float64,
                δt  ::Float64,
                srδt::Float64)

  t0, na, nn =
    _sim_gbmbd(e(bi), lλ(ξc)[1], lμ(ξc)[1], α, σλ, σμ, δt, srδt, 0, 1, 1_000)

  if na < 1 || nn > 999
    return t0, NaN, NaN, NaN, NaN, NaN, NaN
  end

  ntp = na

  lU = -randexp() #log-probability

  # continue simulation only if acr on sum of tip rates is accepted
  acr  = log(ntp/nt(bi))

  # add sampling fraction
  nac  = ni(bi)                # current ni
  Iρi  = (1.0 - ρi(bi))        # branch sampling fraction
  acr -= Float64(nac) * (iszero(Iρi) ? 0.0 : log(Iρi))

  # sample and fix random  tip
  λf, μf = fixrtip!(t0, na, NaN, NaN) # fix random tip

  llrd, acrd, drλ, ssrλ, ssrμ, irrλ, irrμ, λ1p, λ2p, μ1p, μ2p =
    _daughters_update!(ξ1, ξ2, λf, μf, α, σλ, σμ, δt, srδt)

  acr += acrd

  if lU < acr

    # simulate remaining tips until the present
    if na > 1
      tx, na, nn, acr =
        tip_sims!(t0, tf(bi), α, σλ, σμ, δt, srδt, acr, lU, Iρi, na, nn)
    end

    if lU < acr
      na -= 1

      llr = llrd + (na - nac)*(iszero(Iρi) ? 0.0 : log(Iρi))
      l1  = lastindex(λ1p)
      l2  = lastindex(λ2p)
      setnt!(bi, ntp)                       # set new nt
      setni!(bi, na)                        # set new ni
      setλt!(bi, λf)                        # set new λt
      unsafe_copyto!(lλ(ξ1), 1, λ1p, 1, l1) # set new daughter 1 λ vector
      unsafe_copyto!(lλ(ξ2), 1, λ2p, 1, l2) # set new daughter 2 λ vector
      unsafe_copyto!(lμ(ξ1), 1, μ1p, 1, l1) # set new daughter 1 μ vector
      unsafe_copyto!(lμ(ξ2), 1, μ2p, 1, l2) # set new daughter 2 μ vector

      return t0, llr, drλ, ssrλ, ssrμ, irrλ, irrμ
    end
  end

  return t0, NaN, NaN, NaN, NaN, NaN, NaN
end




"""
    tip_sims!(tree::iTbd,
              t   ::Float64,
              α   ::Float64,
              σλ  ::Float64,
              σμ  ::Float64,
              δt  ::Float64,
              srδt::Float64,
              lr  ::Float64,
              lU  ::Float64,
              Iρi ::Float64,
              na  ::Int64,
              nn  ::Int64)

Continue simulation until time `t` for unfixed tips in `tree`.
"""
function tip_sims!(tree::iTbd,
                   t   ::Float64,
                   α   ::Float64,
                   σλ  ::Float64,
                   σμ  ::Float64,
                   δt  ::Float64,
                   srδt::Float64,
                   lr  ::Float64,
                   lU  ::Float64,
                   Iρi ::Float64,
                   na  ::Int64,
                   nn  ::Int64)

  if lU < lr && nn < 1_000

    if istip(tree)
      if !isfix(tree) && isalive(tree)

        fdti = fdt(tree)
        lλ0  = lλ(tree)
        lμ0  = lμ(tree)
        l    = lastindex(lλ0)

        # simulate
        stree, na, nn, lr =
          _sim_gbmbd_it(max(δt-fdti, 0.0), t, lλ0[l], lμ0[l], α, σλ, σμ, δt,
            srδt, lr, lU, Iρi, na-1, nn, 1_000)

        if isnan(lr) || nn > 999
          return tree, na, nn, NaN
        end

        setproperty!(tree, :iμ, isextinct(stree))
        sete!(tree, e(tree) + e(stree))

        lλs = lλ(stree)
        lμs = lμ(stree)

        if lastindex(lλs) === 2
          setfdt!(tree, fdt(tree) + fdt(stree))
        else
          setfdt!(tree, fdt(stree))
        end

        pop!(lλ0)
        pop!(lμ0)
        popfirst!(lλs)
        popfirst!(lμs)
        append!(lλ0, lλs)
        append!(lμ0, lμs)

        if isdefined(stree, :d1)
          tree.d1 = stree.d1
          tree.d2 = stree.d2
        end
      end
    else
      tree.d1, na, nn, lr =
        tip_sims!(tree.d1, t, α, σλ, σμ, δt, srδt, lr, lU, Iρi, na, nn)
      tree.d2, na, nn, lr =
        tip_sims!(tree.d2, t, α, σλ, σμ, δt, srδt, lr, lU, Iρi, na, nn)
    end

    return tree, na, nn, lr
  end

  return tree, na, nn, NaN
end



