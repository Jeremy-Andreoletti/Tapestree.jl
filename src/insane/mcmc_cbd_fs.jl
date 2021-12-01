#=

constant birth-death MCMC using forward simulation

Ignacio Quintero Mächler

t(-_-t)

Created 25 08 2020
=#




"""
    insane_cbd_fs(tree    ::sT_label, 
                  out_file::String,
                  λprior  ::Float64,
                  μprior  ::Float64,
                  niter   ::Int64,
                  nthin   ::Int64,
                  nburn   ::Int64,
                  tune_int::Int64,
                  ϵi      ::Float64,
                  λi      ::Float64,
                  μi      ::Float64,
                  λtni    ::Float64,
                  μtni    ::Float64,
                  obj_ar  ::Float64,
                  pupdp   ::NTuple{3,Float64},
                  prints  ::Int64)

Run insane for constant pure-birth.
"""
function insane_cbd_fs(tree    ::sT_label, 
                       out_file::String,
                       λprior  ::Float64,
                       μprior  ::Float64,
                       niter   ::Int64,
                       nthin   ::Int64,
                       nburn   ::Int64,
                       tune_int::Int64,
                       ϵi      ::Float64,
                       λi      ::Float64,
                       μi      ::Float64,
                       λtni    ::Float64,
                       μtni    ::Float64,
                       obj_ar  ::Float64,
                       pupdp   ::NTuple{3,Float64},
                       prints  ::Int64,
                       tρ      ::Dict{String, Float64})

  n  = ntips(tree)

  # set tips sampling fraction
  if isone(length(tρ))
    tl = tiplabels(tree)
    tρu = tρ[""]
    tρ = Dict(tl[i] => tρu for i in 1:n)
  end

  # make fix tree directory
  idf = make_idf(tree, tρ)

  # starting parameters
  if isnan(λi) && isnan(μi)
    λc, μc = moments(Float64(n), ti(idf[1]), ϵi)
  else
    λc, μc = λi, μi
  end

  # make a decoupled tree and fix it
  Ψ = make_Ψ(idf, sTbd)

  # make parameter updates scaling function for tuning
  spup = sum(pupdp)
  pup  = Int64[]
  for i in Base.OneTo(3) 
    append!(pup, fill(i, ceil(Int64, Float64(2*n - 1) * pupdp[i]/spup)))
  end

  # make objecting scaling function for tuning
  scalef = makescalef(obj_ar)

  # conditioning functions
  sns = (BitVector(), BitVector(), BitVector())
  snodes! = make_snodes(idf, !iszero(e(tree)), sTbd)
  snodes!(Ψ, sns)
  scond, scond0 = make_scond(idf, !iszero(e(tree)), sTbd)

  @info "Running constant birth-death with forward simulation"

  # adaptive phase
  llc, prc, λc, μc, λtn, μtn,= 
      mcmc_burn_cbd(Ψ, n, tune_int, λprior, μprior, nburn, λc, μc, λtni, μtni, 
        scalef, idf, pup, prints, sns, snodes!, scond, scond0)

  # mcmc
  R, treev = mcmc_cbd(Ψ, llc, prc, λc, μc, λprior, μprior, niter, nthin, 
    λtn, μtn, idf, pup, prints, sns, snodes!, scond, scond0)

  pardic = Dict(("lambda"      => 1),
                ("mu"          => 2))

  write_ssr(R, pardic, out_file)

  return R, treev
end





"""
    mcmc_burn_cbd(Ψ       ::Vector{sTbd},
                  n       ::Int64,
                  tune_int::Int64,
                  λprior  ::Float64,
                  μprior  ::Float64,
                  nburn   ::Int64,
                  λc      ::Float64,
                  μc      ::Float64,
                  λtni    ::Float64, 
                  μtni    ::Float64, 
                  scalef  ::Function,
                  idf     ::Array{iBffs,1},
                  pup     ::Array{Int64,1}, 
                  prints  ::Int64,
                  sns     ::NTuple{3, BitVector},
                  snodes! ::Function,
                  scond   ::Function,
                  scond0  ::Function)

Adaptive MCMC phase for da chain for constant birth-death using forward
simulation.
"""
function mcmc_burn_cbd(Ψ       ::Vector{sTbd},
                       n       ::Int64,
                       tune_int::Int64,
                       λprior  ::Float64,
                       μprior  ::Float64,
                       nburn   ::Int64,
                       λc      ::Float64,
                       μc      ::Float64,
                       λtni    ::Float64, 
                       μtni    ::Float64, 
                       scalef  ::Function,
                       idf     ::Array{iBffs,1},
                       pup     ::Array{Int64,1}, 
                       prints  ::Int64,
                       sns     ::NTuple{3, BitVector},
                       snodes! ::Function,
                       scond   ::Function,
                       scond0  ::Function)

  # initialize acceptance log
  ltn = 0
  lup = Float64[0.0,0.0]
  lac = Float64[0.0,0.0]
  λtn = λtni
  μtn = μtni


  el = lastindex(idf)
  L  = treelength(Ψ)     # tree length
  ns = Float64(el-1)/2.0 # number of speciation events
  ne = 0.0               # number of extinction events

  # likelihood
  llc = llik_cbd(Ψ, idf, λc, μc) + scond(λc, μc, sns) + prob_ρ(idf)
  prc = logdexp(λc, λprior) + logdexp(μc, μprior)

  pbar = Progress(nburn, prints, "burning mcmc...", 20)

  for it in Base.OneTo(nburn)

    shuffle!(pup)

    for p in pup

      # λ proposal
      if p === 1
        llc, prc, λc = 
          update_λ!(Ψ, llc, prc, λc, lac, λtn, μc, ns, L, sns, λprior, 
            scond, 1.0)
        lup[1] += 1.0
      end

      # μ proposal
      if p === 2
        llc, prc, μc = 
          update_μ!(Ψ, llc, prc, μc, lac, μtn, λc, ne, L, sns, μprior, 
            scond, 1.0)
        lup[2] += 1.0
      end

      # forward simulation proposal proposal
      if p === 3
        bix = fIrand(el) + 1
        llc, ns, ne, L = update_fs!(bix, Ψ, idf, llc, λc, μc, ns, ne, L, sns,
                           snodes!, scond0, 1.0)

      end

      # log tuning parameters
      ltn += 1
      if ltn == tune_int
        λtn = scalef(λtn,lac[1]/lup[1])
        μtn = scalef(μtn,lac[2]/lup[2])
        ltn = 0
      end
    end

    next!(pbar)
  end

  return llc, prc, λc, μc, λtn, μtn
end





"""
    mcmc_cbd(Ψ     ::Vector{sTbd},
             llc   ::Float64,
             prc   ::Float64,
             λc    ::Float64,
             μc    ::Float64,
             λprior::Float64,
             μprior::Float64,
             niter ::Int64,
             nthin ::Int64,
             λtn   ::Float64,
             μtn   ::Float64, 
             idf   ::Array{iBffs,1},
             pup   ::Array{Int64,1}, 
             prints::Int64,
             scond ::Function)

MCMC da chain for constant birth-death using forward simulation.
"""
function mcmc_cbd(Ψ      ::Vector{sTbd},
                  llc    ::Float64,
                  prc    ::Float64,
                  λc     ::Float64,
                  μc     ::Float64,
                  λprior ::Float64,
                  μprior ::Float64,
                  niter  ::Int64,
                  nthin  ::Int64,
                  λtn    ::Float64,
                  μtn    ::Float64, 
                  idf    ::Array{iBffs,1},
                  pup    ::Array{Int64,1}, 
                  prints ::Int64,
                  sns    ::NTuple{3, BitVector},
                  snodes!::Function,
                  scond  ::Function,
                  scond0 ::Function)

  el = lastindex(idf)
  ns = Float64(nnodesinternal(Ψ))
  ne = Float64(ntipsextinct(Ψ))
  L  = treelength(Ψ)

  # logging
  nlogs = fld(niter,nthin)
  lthin, lit = 0, 0

  # parameter results
  R = Array{Float64,2}(undef, nlogs, 5)

  # make tree vector
  treev  = sTbd[]

  pbar = Progress(niter, prints, "running mcmc...", 20)

  for it in Base.OneTo(niter)

    shuffle!(pup)

    for p in pup

      # λ proposal
      if p === 1
        llc, prc, λc = 
          update_λ!(Ψ, llc, prc, λc, λtn, μc, ns, L, sns, λprior, scond, 1.0)

        # llci = llik_cbd(Ψ, idf, λc, μc) + scond(λc, μc, sns) + prob_ρ(idf)
        # if !isapprox(llci, llc, atol = 1e-6)
        #    @show llci, llc, i, p
        #    return 
        # end
      end

      # μ proposal
      if p === 2
        llc, prc, μc = 
          update_μ!(Ψ, llc, prc, μc, μtn, λc, ne, L, sns, μprior, scond, 1.0)

        # llci = llik_cbd(Ψ, idf, λc, μc) + scond(λc, μc, sns) + prob_ρ(idf)
        # if !isapprox(llci, llc, atol = 1e-6)
        #    @show llci, llc, i, p
        #    return 
        # end
      end

      # forward simulation proposal proposal
      if p === 3
        bix = ceil(Int64,rand()*el)
        llc, ns, ne, L = update_fs!(bix, Ψ, idf, llc, λc, μc, ns, ne, L, sns,
                           snodes!, scond0, 1.0)

        # llci = llik_cbd(Ψ, idf, λc, μc) + scond(λc, μc, sns) + prob_ρ(idf)
        # if !isapprox(llci, llc, atol = 1e-6)
        #    @show llci, llc, i, p
        #    return 
        # end
      end
    end

    # log parameters
    lthin += 1
    if lthin == nthin

      lit += 1
      @inbounds begin
        R[lit,1] = Float64(lit)
        R[lit,2] = llc
        R[lit,3] = prc
        R[lit,4] = λc
        R[lit,5] = μc
        push!(treev, couple(deepcopy(Ψ), idf, 1))
      end
      lthin = 0
    end

    next!(pbar)
  end

  return R, treev
end




"""
    marginal_likelihood(Ψ      ::Vector{sTbd},
                        llc    ::Float64,
                        prc    ::Float64,
                        λc     ::Float64,
                        μc     ::Float64,
                        λprior ::Float64,
                        μprior ::Float64,
                        niter  ::Int64,
                        nthin  ::Int64,
                        λtn    ::Float64,
                        μtn    ::Float64, 
                        idf    ::Array{iBffs,1},
                        pup    ::Array{Int64,1}, 
                        prints ::Int64,
                        sns    ::NTuple{3, BitVector},
                        snodes!::Function,
                        scond  ::Function,
                        scond0 ::Function)

MCMC da chain for constant birth-death using forward simulation.
"""
function marginal_likelihood(Ψ      ::Vector{sTbd},
                             llc    ::Float64,
                             prc    ::Float64,
                             λc     ::Float64,
                             μc     ::Float64,
                             λprior ::Float64,
                             μprior ::Float64,
                             niter  ::Int64,
                             nthin  ::Int64,
                             λtn    ::Float64,
                             μtn    ::Float64, 
                             idf    ::Array{iBffs,1},
                             pup    ::Array{Int64,1}, 
                             prints ::Int64,
                             sns    ::NTuple{3, BitVector},
                             snodes!::Function,
                             scond  ::Function,
                             scond0 ::Function)




  # powers
  K      = 10 # number of quantiles
  β_dist = (0.3, 1.0)
  β      = [0.0:0.1:0.9...]

  # n per power
  niter = 100
  nthin = 10

  #




  el = lastindex(idf)
  ns = Float64(nnodesinternal(Ψ))
  ne = Float64(ntipsextinct(Ψ))
  L  = treelength(Ψ)

  # logging
  nlogs = fld(niter,nthin)
  lthin, lit = 0, 0

  # parameter results
  R = Array{Float64,2}(undef, nlogs, 5)

  # make tree vector
  treev  = sTbd[]

  pbar = Progress(niter, prints, "running mcmc...", 20)

  for it in Base.OneTo(niter)

    shuffle!(pup)

    for p in pup

      # λ proposal
      if p === 1
        llc, prc, λc = 
          update_λ!(Ψ, llc, prc, λc, λtn, μc, ns, L, sns, λprior, scond, 1.0)

        # llci = llik_cbd(Ψ, idf, λc, μc) + scond(λc, μc, sns) + prob_ρ(idf)
        # if !isapprox(llci, llc, atol = 1e-6)
        #    @show llci, llc, i, p
        #    return 
        # end
      end

      # μ proposal
      if p === 2
        llc, prc, μc = 
          update_μ!(Ψ, llc, prc, μc, μtn, λc, ne, L, sns, μprior, scond, 1.0)

        # llci = llik_cbd(Ψ, idf, λc, μc) + scond(λc, μc, sns) + prob_ρ(idf)
        # if !isapprox(llci, llc, atol = 1e-6)
        #    @show llci, llc, i, p
        #    return 
        # end
      end

      # forward simulation proposal proposal
      if p === 3
        bix = ceil(Int64,rand()*el)
        llc, ns, ne, L = update_fs!(bix, Ψ, idf, llc, λc, μc, ns, ne, L, sns,
                           snodes!, scond0, 1.0)

        # llci = llik_cbd(Ψ, idf, λc, μc) + scond(λc, μc, sns) + prob_ρ(idf)
        # if !isapprox(llci, llc, atol = 1e-6)
        #    @show llci, llc, i, p
        #    return 
        # end
      end
    end

    # log parameters
    lthin += 1
    if lthin == nthin

      lit += 1
      @inbounds begin
        R[lit,1] = Float64(lit)
        R[lit,2] = llc
        R[lit,3] = prc
        R[lit,4] = λc
        R[lit,5] = μc
        push!(treev, couple(deepcopy(Ψ), idf, 1))
      end
      lthin = 0
    end

    next!(pbar)
  end

  return R, treev
end





"""
    update_fs!(bix  ::Int64,
               Ψ    ::Vector{sTbd},
               idf  ::Vector{iBffs},
               llc  ::Float64,
               λ    ::Float64, 
               μ    ::Float64,
               ns   ::Float64,
               ne   ::Float64,
               L    ::Float64,
               scond::Function,
               pow  ::Float64)

Forward simulation proposal function for constant birth-death.
"""
function update_fs!(bix    ::Int64,
                    Ψ      ::Vector{sTbd},
                    idf    ::Vector{iBffs},
                    llc    ::Float64,
                    λ      ::Float64, 
                    μ      ::Float64,
                    ns     ::Float64,
                    ne     ::Float64,
                    L      ::Float64,
                    sns    ::NTuple{3, BitVector},
                    snodes!::Function,
                    scond0 ::Function,
                    pow    ::Float64)

  bi = idf[bix]

  # forward simulate an internal branch
  ψp, np, ntp = fsbi(bi, λ, μ, 500)

  itb = it(bi) # is it terminal
  ρbi = ρi(bi) # get branch sampling fraction
  nc  = ni(bi) # current ni
  ntc = nt(bi) # current nt

  if np > 0

    # current tree
    ψc  = Ψ[bix]

    # if terminal branch
    if itb
      llr = log(Float64(np)/Float64(nc) * (1.0 - ρbi)^(np - nc))
      acr = pow * llr
    else
      np  -= 1
      llr = pow * log((1.0 - ρbi)^(np - nc))
      acr = llr + log(Float64(ntp)/Float64(ntc))
    end

    # MH ratio
    if -randexp() < acr

      # if stem conditioned
      if (iszero(pa(bi)) && e(bi) > 0.0) || (isone(pa(bi)) && iszero(e(Ψ[1])))
          llr += pow * (scond0(ψp, λ, μ, itb) - scond0(ψc, λ, μ, itb))
      end

      # update ns, ne & L
      ns += Float64(nnodesinternal(ψp) - nnodesinternal(ψc))
      ne += Float64(ntipsextinct(ψp)   - ntipsextinct(ψc))
      L  += treelength(ψp) - treelength(ψc)

      # likelihood ratio
      llr += pow * (llik_cbd(ψp, λ, μ) - llik_cbd(ψc, λ, μ))

      Ψ[bix] = ψp     # set new decoupled tree
      llc += llr      # set new likelihood
      snodes!(Ψ, sns) # set new sns
      setni!(bi, np)  # set new ni
      setnt!(bi, ntp) # set new nt
    end
  end

  return llc, ns, ne, L
end





"""
    fsbi(bi::iBffs, λ::Float64, μ::Float64, ntry::Int64)

Forward simulation for branch `bi`
"""
function fsbi(bi::iBffs, λ::Float64, μ::Float64, ntry::Int64)

  # times
  tfb = tf(bi)

  ext = 0
  # condition on non-extinction (helps in mixing)
  while ext < ntry 
    ext += 1

    # forward simulation during branch length
    t0, na = sim_cbd(e(bi), λ, μ, 0)

    nat = na

    if isone(na)
      fixalive!(t0)

      return t0, na, nat
    elseif na > 1
      # fix random tip
      fixrtip!(t0)

      if !it(bi)
        # add tips until the present
        tx, na = tip_sims!(t0, tfb, λ, μ, na)
      end

      return t0, na, nat
    end
  end

  return sTbd(), 0, 0
end




"""
    tip_sims!(tree::sTbd, t::Float64, λ::Float64, μ::Float64)

Continue simulation until time `t` for unfixed tips in `tree`. 
"""
function tip_sims!(tree::sTbd, t::Float64, λ::Float64, μ::Float64, na::Int64)

  if istip(tree) 
    if !isfix(tree) && isalive(tree)

      # simulate
      stree, na = sim_cbd(t, λ, μ, na-1)

      # merge to current tip
      sete!(tree, e(tree) + e(stree))
      setproperty!(tree, :iμ, isextinct(stree))
      if isdefined(stree, :d1)
        tree.d1 = stree.d1
        tree.d2 = stree.d2
      end
    end
  else
    tree.d1, na = tip_sims!(tree.d1, t, λ, μ, na)
    tree.d2, na = tip_sims!(tree.d2, t, λ, μ, na)
  end

  return tree, na
end




"""
    update_λ!(psi   ::Vector{sTbd},
              llc   ::Float64,
              prc   ::Float64,
              λc    ::Float64,
              lac   ::Array{Float64,1},
              λtn   ::Float64,
              μc    ::Float64,
              ns    ::Float64,
              L     ::Float64,
              sns   ::NTuple{3,BitVector},
              λprior::Float64,
              scond ::Function,
              pow   ::Float64)

`λ` proposal function for constant birth-death in adaptive phase.
"""
function update_λ!(psi   ::Vector{sTbd},
                   llc   ::Float64,
                   prc   ::Float64,
                   λc    ::Float64,
                   lac   ::Array{Float64,1},
                   λtn   ::Float64,
                   μc    ::Float64,
                   ns    ::Float64,
                   L     ::Float64,
                   sns   ::NTuple{3,BitVector},
                   λprior::Float64,
                   scond ::Function,
                   pow   ::Float64)

    λp = mulupt(λc, λtn)::Float64

    λr  = log(λp/λc)
    llr = ns*λr + L*(λc - λp) + scond(λp, μc, sns) - scond(λc, μc, sns)
    prr = llrdexp_x(λp, λc, λprior)

    if -randexp() < (pow * llr + prr + λr)
      llc    += llr
      prc    += prr
      λc      = λp
      lac[1] += 1.0
    end

    return llc, prc, λc
end




"""
    update_λ!(psi   ::Vector{sTbd},
              llc   ::Float64,
              prc   ::Float64,
              λc    ::Float64,
              λtn   ::Float64,
              μc    ::Float64,
              ns    ::Float64,
              L     ::Float64,
              sns   ::NTuple{3,BitVector},
              λprior::Float64,
              scond ::Function,
              pow   ::Float64)

`λ` proposal function for constant birth-death.
"""
function update_λ!(psi   ::Vector{sTbd},
                   llc   ::Float64,
                   prc   ::Float64,
                   λc    ::Float64,
                   λtn   ::Float64,
                   μc    ::Float64,
                   ns    ::Float64,
                   L     ::Float64,
                   sns   ::NTuple{3,BitVector},
                   λprior::Float64,
                   scond ::Function,
                   pow   ::Float64)

    λp = mulupt(λc, rand() < 0.3 ? λtn : 4.0*λtn)::Float64

    λr  = log(λp/λc)
    llr = ns*λr + L*(λc - λp) + scond(λp, μc, sns) - scond(λc, μc, sns)
    prr = llrdexp_x(λp, λc, λprior)

    if -randexp() < (pow * llr + prr + λr)
      llc += llr
      prc += prr
      λc   = λp
    end

    return llc, prc, λc 
end




"""
    update_μ!(psi   ::Vector{sTbd},
              llc   ::Float64,
              prc   ::Float64,
              μc    ::Float64,
              lac   ::Array{Float64,1},
              μtn   ::Float64,
              λc    ::Float64,
              ne    ::Float64,
              L     ::Float64,
              sns   ::NTuple{3,BitVector},
              μprior::Float64,
              scond ::Function,
              pow   ::Float64)

`μ` proposal function for constant birth-death in adaptive phase.
"""
function update_μ!(psi   ::Vector{sTbd},
                   llc   ::Float64,
                   prc   ::Float64,
                   μc    ::Float64,
                   lac   ::Array{Float64,1},
                   μtn   ::Float64,
                   λc    ::Float64,
                   ne    ::Float64,
                   L     ::Float64,
                   sns   ::NTuple{3,BitVector},
                   μprior::Float64,
                   scond ::Function,
                   pow   ::Float64)

    μp = mulupt(μc, μtn)::Float64

    μr  = log(μp/μc)
    llr = ne*μr + L*(μc - μp) + scond(λc, μp, sns) - scond(λc, μc, sns)
    prr = llrdexp_x(μp, μc, μprior)

    if -randexp() < (pow * llr + prr + μr)
      llc    += llr
      prc    += prr
      μc      = μp
      lac[2] += 1.0
    end

    return llc, prc, μc 
end




"""
    update_μ!(psi   ::Vector{sTbd},
              llc   ::Float64,
              prc   ::Float64,
              μc    ::Float64,
              μtn   ::Float64,
              λc    ::Float64,
              ne    ::Float64,
              L     ::Float64,
              sns   ::NTuple{3,BitVector},
              μprior::Float64,
              scond ::Function,
              pow   ::Float64)

`μ` proposal function for constant birth-death.
"""
function update_μ!(psi   ::Vector{sTbd},
                   llc   ::Float64,
                   prc   ::Float64,
                   μc    ::Float64,
                   μtn   ::Float64,
                   λc    ::Float64,
                   ne    ::Float64,
                   L     ::Float64,
                   sns   ::NTuple{3,BitVector},
                   μprior::Float64,
                   scond ::Function,
                   pow   ::Float64)

    μp = mulupt(μc, rand() < 0.3 ? μtn : 4.0*μtn)::Float64

    μr  = log(μp/μc)
    llr = ne*μr + L*(μc - μp) + scond(λc, μp, sns) - scond(λc, μc, sns)
    prr = llrdexp_x(μp, μc, μprior)

    if -randexp() < (pow * llr + prr + μr)
      llc += llr
      prc += prr
      μc   = μp
    end

    return llc, prc, μc 
end




