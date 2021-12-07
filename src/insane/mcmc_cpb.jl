#=

pure-birth MCMC

Ignacio Quintero Mächler

t(-_-t)

Created 06 07 2020
=#




"""
    insane_cpb(tree    ::sT_label, 
               out_file::String;
               λprior  ::NTuple{2,Float64}     = (1.0, 1.0),
               niter   ::Int64                 = 1_000,
               nthin   ::Int64                 = 10,
               nburn   ::Int64                 = 200,
               tune_int::Int64                 = 100,
               marginal    ::Bool                  = false,
               nitpp   ::Int64                 = 100, 
               nthpp   ::Int64                 = 10,
               K       ::Int64                 = 10,
               λi      ::Float64               = NaN,
               pupdp   ::NTuple{2,Float64}     = (0.2, 0.2),
               prints  ::Int64                 = 5,
               tρ      ::Dict{String, Float64} = Dict("" => 1.0))

Run insane for constant pure-birth.
"""
function insane_cpb(tree    ::sT_label, 
                    out_file::String;
                    λprior  ::NTuple{2,Float64}     = (1.0, 1.0),
                    niter   ::Int64                 = 1_000,
                    nthin   ::Int64                 = 10,
                    nburn   ::Int64                 = 200,
                    tune_int::Int64                 = 100,
                    marginal    ::Bool                  = false,
                    nitpp   ::Int64                 = 100, 
                    nthpp   ::Int64                 = 10,
                    K       ::Int64                 = 10,
                    λi      ::Float64               = NaN,
                    pupdp   ::NTuple{2,Float64}     = (0.2, 0.2),
                    prints  ::Int64                 = 5,
                    tρ      ::Dict{String, Float64} = Dict("" => 1.0))

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
  if isnan(λi)
    λc = Float64(n-2)/treelength(tree)
  else
    λc = λi
  end

  # make a decoupled tree and fix it
  Ψ = sTpb[]
  sTpb!(Ψ, tree)

  # make parameter updates scaling function for tuning
  spup = sum(pupdp)
  pup  = Int64[]
  for i in Base.OneTo(2) 
    append!(pup, fill(i, ceil(Int64, Float64(2*n - 1) * pupdp[i]/spup)))
  end

  @info "Running constant pure-birth with forward simulation"

  # adaptive phase
  llc, prc, λc = 
      mcmc_burn_cpb(Ψ, idf, λprior, nburn, λc, pup, prints)

  # mcmc
  r, treev = mcmc_cpb(Ψ, idf, llc, prc, λc, λprior, niter, nthin, pup, prints)

  pardic = Dict(("lambda" => 1))

  write_ssr(r, pardic, out_file)

  if marginal
    # reference distribution
    βs = [range(0.0, 1.0, K)...]
    reverse!(βs)

    @views p = r[:,4]

    # make reference posterior
    m     = mean(p)
    v     = var(p)
    λrefd = (m^2/v, m/v)

    # marginal likelihood
    pp = ref_posterior(Ψ, idf, llc, prc, λc, λprior, λrefd, 
      nitpp, nthpp, βs, pup)

    # process with reference distribution the posterior
    p1 = Vector{Float64}(undef, size(r,1))
    for i in Base.OneTo(size(r,1))
      p1[i] = r[i,2] + r[i,3] - logdgamma(r[i,4], λrefd[1], λrefd[2])
    end
    pp[1] = p1

    reverse!(pp)
    reverse!(βs)

    ml = gss(pp, βs)
  else
    ml = NaN
  end

  return r, treev, ml
end




"""
    mcmc_burn_cpb(Ψ       ::Vector{sTpb}, 
                  idf     ::Array{iBffs,1},
                  λprior  ::NTuple{2,Float64},
                  nburn   ::Int64,
                  λc      ::Float64,
                  pup     ::Array{Int64,1}, 
                  prints  ::Int64)

MCMC chain for constant pure-birth.
"""
function mcmc_burn_cpb(Ψ       ::Vector{sTpb}, 
                       idf     ::Array{iBffs,1},
                       λprior  ::NTuple{2,Float64},
                       nburn   ::Int64,
                       λc      ::Float64,
                       pup     ::Array{Int64,1}, 
                       prints  ::Int64)

  el = lastindex(idf)
  L  = treelength(Ψ)     # tree length
  ns = Float64(el-1)*0.5 # number of speciation events

  #likelihood
  llc = llik_cpb(Ψ, λc) + prob_ρ(idf)
  prc = logdgamma(λc, λprior[1], λprior[2])

  pbar = Progress(nburn, prints, "burning mcmc...", 20)

  for it in Base.OneTo(nburn)

    shuffle!(pup)

    for p in pup

      # λ proposal
      if p === 1

        llc, prc, λc = update_λ!(llc, prc, λc, ns, L, λprior, 1.0)

      # forward simulation proposal proposal
      else
        bix = ceil(Int64,rand()*el)

        llc, ns, L = update_fs!(bix, Ψ, idf, llc, λc, ns, L, 1.0)
      end
    end

    next!(pbar)
  end

  return llc, prc, λc
end




"""
    mcmc_cpb(Ψ      ::Vector{sTpb},
             idf    ::Array{iBffs,1},
             llc    ::Float64,
             prc    ::Float64,
             λc     ::Float64,
             λprior ::NTuple{2,Float64},
             niter  ::Int64,
             nthin  ::Int64,
             pup    ::Array{Int64,1}, 
             prints ::Int64)

MCMC chain for constant pure-birth.
"""
function mcmc_cpb(Ψ      ::Vector{sTpb},
                  idf    ::Array{iBffs,1},
                  llc    ::Float64,
                  prc    ::Float64,
                  λc     ::Float64,
                  λprior ::NTuple{2,Float64},
                  niter  ::Int64,
                  nthin  ::Int64,
                  pup    ::Array{Int64,1}, 
                  prints ::Int64)

  el = lastindex(idf)
  ns = Float64(nnodesinternal(Ψ))
  L  = treelength(Ψ)

  # logging
  nlogs = fld(niter,nthin)
  lthin, lit = 0, 0

  R = Array{Float64,2}(undef, nlogs, 4)

  # make tree vector
  treev  = sTpb[]

  pbar = Progress(niter, prints, "running mcmc...", 20)

  for it in Base.OneTo(niter)

    shuffle!(pup)

    for p in pup

      # λ proposal
      if p === 1

        llc, prc, λc = update_λ!(llc, prc, λc, ns, L, λprior, 1.0)

        # llci = llik_cpb(Ψ, λc)
        # if !isapprox(llci, llc, atol = 1e-6)
        #    @show llci, llc, it, p
        #    return 
        # end
      # forward simulation proposal proposal
      else

        bix = ceil(Int64,rand()*el)
        llc, ns, L = update_fs!(bix, Ψ, idf, llc, λc, ns, L, 1.0)

        # llci = llik_cpb(Ψ, λc)
        # if !isapprox(llci, llc, atol = 1e-6)
        #    @show llci, llc, it, p
        #    return 
        # end
      end
    end

    lthin += 1
    if lthin == nthin
      lit += 1
      @inbounds begin
        R[lit,1] = Float64(lit)
        R[lit,2] = llc
        R[lit,3] = prc
        R[lit,4] = λc
        push!(treev, couple(deepcopy(Ψ), idf, 1))
      end
      lthin = 0
    end

    next!(pbar)
  end

  return R, treev
end




"""
    ref_posterior(Ψ      ::Vector{sTpb},
                  idf    ::Array{iBffs,1},
                  llc    ::Float64,
                  prc    ::Float64,
                  λc     ::Float64,
                  λprior ::NTuple{2,Float64},
                  nitpp  ::Int64,
                  nthpp  ::Int64,
                  βs     ::Vector{Float64},
                  pup    ::Array{Int64,1})

MCMC da chain for constant birth-death using forward simulation.
"""
function ref_posterior(Ψ      ::Vector{sTpb},
                       idf    ::Array{iBffs,1},
                       llc    ::Float64,
                       prc    ::Float64,
                       λc     ::Float64,
                       λprior ::NTuple{2,Float64},
                       λrefd  ::NTuple{2,Float64},
                       nitpp  ::Int64,
                       nthpp  ::Int64,
                       βs     ::Vector{Float64},
                       pup    ::Array{Int64,1})

  K = lastindex(βs)

  # make log-likelihood table per power
  nlg = fld(nitpp, nthpp)
  pp  = [Vector{Float64}(undef,nlg) for i in Base.OneTo(K)]

  el = lastindex(idf)
  ns = Float64(nnodesinternal(Ψ))
  L  = treelength(Ψ)

  llc = llik_cpb(Ψ, λc) + prob_ρ(idf)
  prc = logdgamma(λc, λprior[1], λprior[2])

  for k in 2:K

    βi  = βs[k]
    rdc = logdgamma(λc, λrefd[1], λrefd[2])

    # logging
    lth, lit = 0, 0

    for it in Base.OneTo(nitpp)

      shuffle!(pup)

      for p in pup

        # λ proposal
        if p === 1

          llc, prc, rdc, λc = 
            update_λ!(llc, prc, rdc, λc, ns, L, λprior, λrefd, βi)

        # forward simulation proposal proposal
        else 

          bix = ceil(Int64,rand()*el)
          llc, ns, L = update_fs!(bix, Ψ, idf, llc, λc, ns, L, βi)

        end
      end

      # log log-likelihood
      lth += 1
      if lth === nthpp
        lit += 1
        pp[k][lit] = llc + prc - rdc
        lth = 0
      end
    end

    @info string(βi," power done")
  end

  return pp
end




"""
    update_fs!(bix    ::Int64,
               Ψ      ::Vector{sTpb},
               idf    ::Vector{iBffs},
               llc    ::Float64,
               λ      ::Float64, 
               ns     ::Float64,
               L      ::Float64,
               pow    ::Float64)

Forward simulation proposal function for constant pure-birth.
"""
function update_fs!(bix    ::Int64,
                    Ψ      ::Vector{sTpb},
                    idf    ::Vector{iBffs},
                    llc    ::Float64,
                    λ      ::Float64, 
                    ns     ::Float64,
                    L      ::Float64,
                    pow    ::Float64)

  bi = idf[bix]

  # forward simulate an internal branch
  ψp, np, ntp = fsbi(bi, λ, 1_000)

  itb = it(bi) # is it terminal
  ρbi = ρi(bi) # get branch sampling fraction
  nc  = ni(bi) # current ni
  ntc = nt(bi) # current nt

  if ntp > 0

    # current tree
    ψc  = Ψ[bix]

    # if terminal branch
    if itb
      llr = log(Float64(np)/Float64(nc) * (1.0 - ρbi)^(np - nc))
      acr = 0.0
    else
      np  -= 1
      llr = log((1.0 - ρbi)^(np - nc))
      acr = log(Float64(ntp)/Float64(ntc))
    end

    # MH ratio
    if -randexp() < (pow * llr) + acr

      # update ns, ne & L
      ns += Float64(nnodesinternal(ψp) - nnodesinternal(ψc))
      L  += treelength(ψp)             - treelength(ψc)

      # likelihood ratio
      llr += llik_cpb(ψp, λ) - llik_cpb(ψc, λ)

      Ψ[bix] = ψp     # set new decoupled tree
      llc += llr      # set new likelihood
      setni!(bi, np)  # set new ni
      setnt!(bi, ntp) # set new nt
    end
  end

  return llc, ns, L
end




"""
    fsbi(bi::iBffs, λ::Float64, ntry::Int64)

Forward simulation for branch `bi`
"""
function fsbi(bi::iBffs, λ::Float64, ntry::Int64)

  # times
  tfb = tf(bi)

  ext = 0
  # condition on non-extinction (helps in mixing)
  while ext < ntry 
    ext += 1

    # forward simulation during branch length
    t0, na = sim_cpb(e(bi), λ, 0)

    nat = na

    if isone(na)
      fixalive!(t0)

      return t0, na, nat
    elseif na > 1
      # fix random tip
      fixrtip!(t0)

      if !it(bi)
        # add tips until the present
        tx, na = tip_sims!(t0, tfb, λ, na)
      end

      return t0, na, nat
    end
  end

  return sTpb(), 0, 0
end




"""
    tip_sims!(tree::sTpb, t::Float64, λ::Float64, μ::Float64)

Continue simulation until time `t` for unfixed tips in `tree`. 
"""
function tip_sims!(tree::sTpb, t::Float64, λ::Float64, na::Int64)

  if istip(tree) 
    if !isfix(tree)

      # simulate
      stree, na = sim_cpb(t, λ, na-1)

      # merge to current tip
      sete!(tree, e(tree) + e(stree))
      if isdefined(stree, :d1)
        tree.d1 = stree.d1
        tree.d2 = stree.d2
      end
    end
  else
    tree.d1, na = tip_sims!(tree.d1, t, λ, na)
    tree.d2, na = tip_sims!(tree.d2, t, λ, na)
  end

  return tree, na
end




"""
    update_λ!(psi   ::Vector{sTpb},
              llc   ::Float64,
              prc   ::Float64,
              λc    ::Float64,
              lac   ::Float64,
              λtn   ::Float64,
              ns    ::Float64,
              L     ::Float64,
              λprior::Float64,
              pow   ::Float64)

Gibbs sampling of `λ` for constant pure-birth.
"""
function update_λ!(llc   ::Float64,
                   prc   ::Float64,
                   λc    ::Float64,
                   ns    ::Float64,
                   L     ::Float64,
                   λprior::NTuple{2,Float64},
                   pow   ::Float64)

  λp   = randgamma(λprior[1] + pow * (ns-1.0), λprior[2] + pow * L)

  llc += (ns-1.0)*log(λp/λc) + L*(λc - λp)
  prc += llrdgamma(λp, λc, λprior[1], λprior[2])

  return llc, prc, λp
end




"""
    update_λ!(psi   ::Vector{sTpb},
              llc   ::Float64,
              prc   ::Float64,
              λc    ::Float64,
              lac   ::Float64,
              λtn   ::Float64,
              ns    ::Float64,
              L     ::Float64,
              λprior::Float64,
              pow   ::Float64)

Gibbs sampling of `λ` for constant pure-birth with reference distribution.
"""
function update_λ!(llc   ::Float64,
                   prc   ::Float64,
                   rdc   ::Float64,
                   λc    ::Float64,
                   ns    ::Float64,
                   L     ::Float64,
                   λprior::NTuple{2,Float64},
                   λrefd ::NTuple{2,Float64},
                   pow   ::Float64)

  m1 = iszero(pow) ? 0.0 : - 1.0
  λp = randgamma(pow * (λprior[1] + ns - 1.0) + (1.0 - pow) * λrefd[1] + m1,
                 pow * (λprior[2] + L)        + (1.0 - pow) * λrefd[2]) 

  llc += (ns-1.0)*log(λp/λc) + L*(λc - λp)
  prc += llrdgamma(λp, λc, λprior[1], λprior[2])
  rdc += llrdgamma(λp, λc, λrefd[1],  λrefd[2])

  return llc, prc, rdc, λp
end



"""
  write_ssr(R       ::Array{Float64,2}, 
            pardic  ::Dict{String,Int64},
            out_file::String)

Write the samples from an MC sampler data frame 
given a Dictionary of parameters.
"""
function write_ssr(R       ::Array{Float64,2}, 
                   pardic  ::Dict{String,Int64},
                   out_file::String)

  # column names
  col_nam = ["Iteration", "Likelihood", "Prior"]

  for (k,v) in sort!(collect(pardic), by = x -> x[2])
    push!(col_nam, k)
  end

  R = vcat(reshape(col_nam, 1, lastindex(col_nam)), R)

  writedlm(out_file*".log", R)
end



