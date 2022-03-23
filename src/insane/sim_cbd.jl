#=

constant birth-death simulation

Ignacio Quintero Mächler

t(-_-t)

Created 06 07 2020
=#




"""
    sim_cbd(t::Float64, λ::Float64, μ::Float64)

Simulate a constant birth-death `iTree` of height `t` with speciation rate `λ`
and extinction rate `μ`.
"""
function sim_cbd(t::Float64,
                 λ::Float64,
                 μ::Float64)

  tw = cbd_wait(λ, μ)

  if tw > t
    return sTbd(t)
  end

  if λorμ(λ, μ)
    return sTbd(sim_cbd(t - tw, λ, μ), sim_cbd(t - tw, λ, μ), tw)
  else
    return sTbd(tw, true)
  end
end




"""
    sim_cbd(t ::Float64,
            λ ::Float64,
            μ ::Float64,
            na::Int64)

Simulate a constant birth-death `iTree` of height `t` with speciation rate `λ`
and extinction rate `μ`.
"""
function sim_cbd(t ::Float64,
                 λ ::Float64,
                 μ ::Float64,
                 na::Int64)

  tw = cbd_wait(λ, μ)

  if tw > t
    na += 1
    return sTbd(t), na
  end

  if λorμ(λ, μ)
    d1, na = sim_cbd(t - tw, λ, μ, na)
    d2, na = sim_cbd(t - tw, λ, μ, na)

    return sTbd(d1, d2, tw), na
  else
    return sTbd(tw, true), na
  end
end




"""
    _sim_cbd_t(t   ::Float64,
               λ   ::Float64,
               μ   ::Float64,
               lr  ::Float64,
               lU  ::Float64,
               Iρi ::Float64,
               na  ::Int64,
               nsp ::Int64,
               nlim::Int64)

Simulate a constant birth-death `iTree` of height `t` with speciation rate `λ`
and extinction rate `μ` for terminal branches.
"""
function _sim_cbd_t(t   ::Float64,
                    λ   ::Float64,
                    μ   ::Float64,
                    lr  ::Float64,
                    lU  ::Float64,
                    Iρi ::Float64,
                    na  ::Int64,
                    nsp ::Int64,
                    nlim::Int64)

  if isfinite(lr) && nsp < nlim

    tw = cbd_wait(λ, μ)

    if tw > t
      na += 1
      nlr = lr
      if na > 1
        nlr += log(Iρi * Float64(na)/Float64(na-1))
      end
      if nlr >= lr
        return sTbd(t, false, false), na, nsp, nlr
      elseif lU < nlr
        return sTbd(t, false, false), na, nsp, nlr
      else
        return sTbd(0.0, false, false), na, nsp, NaN
      end
    else
      if λorμ(λ, μ)
        nsp += 1
        d1, na, nsp, lr = _sim_cbd_t(t - tw, λ, μ, lr, lU, Iρi, na, nsp, nlim)
        d2, na, nsp, lr = _sim_cbd_t(t - tw, λ, μ, lr, lU, Iρi, na, nsp, nlim)

        return sTbd(d1, d2, tw, false, false), na, nsp, lr
      else
        return sTbd(tw, true, false), na, nsp, lr
      end
    end
  end

  return sTbd(0.0, false, false), na, nsp, NaN
end




"""
    _sim_cbd_i(t   ::Float64,
               λ   ::Float64,
               μ   ::Float64,
               na  ::Int64,
               nsp ::Int64,
               nlim::Int64)

Simulate a constant birth-death `iTree` of height `t` with speciation rate `λ`
and extinction rate `μ` for internal branches.
"""
function _sim_cbd_i(t   ::Float64,
                    λ   ::Float64,
                    μ   ::Float64,
                    na  ::Int64,
                    nsp ::Int64,
                    nlim::Int64)

  if nsp < nlim

    tw = cbd_wait(λ, μ)

    if tw > t
      na += 1
      return sTbd(t, false, false), na, nsp
    end

    if λorμ(λ, μ)
      nsp += 1
      d1, na, nsp = _sim_cbd_i(t - tw, λ, μ, na, nsp, nlim)
      d2, na, nsp = _sim_cbd_i(t - tw, λ, μ, na, nsp, nlim)

      return sTbd(d1, d2, tw, false, false), na, nsp
    else
      return sTbd(tw, true, false), na, nsp
    end
  end

  return sTbd(0.0, false, false), na, nsp
end




"""
    _sim_cbd_it(t   ::Float64,
                λ   ::Float64,
                μ   ::Float64,
                lr  ::Float64,
                lU  ::Float64,
                Iρi ::Float64,
                nsp ::Int64,
                nlim::Int64)

Simulate a constant birth-death `iTree` of height `t` with speciation rate `λ`
and extinction rate `μ` for continuing internal branches.
"""
function _sim_cbd_it(t   ::Float64,
                     λ   ::Float64,
                     μ   ::Float64,
                     lr  ::Float64,
                     lU  ::Float64,
                     Iρi ::Float64,
                     na  ::Int64,
                     nsp ::Int64,
                     nlim::Int64)

  if lU < lr && nsp < nlim

    tw = cbd_wait(λ, μ)

    if tw > t
      na += 1
      lr += log(Iρi)
      return sTbd(t, false, false), na, nsp, lr
    end

    if λorμ(λ, μ)
      nsp += 1
      d1, na, nsp, lr = _sim_cbd_it(t - tw, λ, μ, lr, lU, Iρi, na, nsp, nlim)
      d2, na, nsp, lr = _sim_cbd_it(t - tw, λ, μ, lr, lU, Iρi, na, nsp, nlim)

      return sTbd(d1, d2, tw, false, false), na, nsp, lr
    else
      return sTbd(tw, true, false), na, nsp, lr
    end

  end

  return sTbd(0.0, false, false), na, nsp, NaN
end




"""
    sim_cbd_surv(t::Float64, λ::Float64, μ::Float64, surv::Bool, nsp::Int64)

Simulate a constant birth-death `iTree` of height `t` with speciation rate `λ`
and extinction rate `μ` until it goes extinct or survives.
"""
function sim_cbd_surv(t   ::Float64,
                      λ   ::Float64,
                      μ   ::Float64,
                      surv::Bool,
                      nsp ::Int64)

  if !surv && nsp < 500

    tw = cbd_wait(λ, μ)

    if tw > t
      return true, nsp
    end

    if λorμ(λ, μ)
      nsp += 1
      surv, nsp = sim_cbd_surv(t - tw, λ, μ, surv, nsp)
      surv, nsp = sim_cbd_surv(t - tw, λ, μ, surv, nsp)

      return surv, nsp
    else
      return surv, nsp
    end
  end

  return true, nsp
end




"""
   sim_cbd_b(n::Int64, λ::Float64, μ::Float64)

Simulate constant birth-death in backward time.
"""
function sim_cbd_b(n::Int64,
                   λ::Float64,
                   μ::Float64)

  nF = Float64(n)
  nI = n

  # disjoint trees vector
  tv = sTbd[]
  for i in Base.OneTo(nI)
    push!(tv, sTbd(0.0))
  end

  # start simulation
  while true
    w = cbd_wait(nF, λ, μ)

    for t in tv
      adde!(t, w)
    end

    # if speciation
    if λorμ(λ, μ)
      if isone(nI)
        return tv[nI]
      else
        j, k = samp2(Base.OneTo(nI))
        tv[j] = sTbd(tv[j], tv[k], 0.0)
        deleteat!(tv,k)
        nI -= 1
        nF -= 1.0
      end
    # if extinction
    else
      nI += 1
      nF += 1.0
      push!(tv, sTbd(0.0, true))
    end
  end
end




"""
    sim_cbd_b(λ::Float64,
              μ::Float64,
              mxth::Float64,
              maxn::Int64)

Simulate constant birth-death in backward time conditioned on 1 survival
and not having a greater tree height than `mxth`.
"""
function sim_cbd_b(λ::Float64,
                   μ::Float64,
                   mxth::Float64,
                   maxn::Int64)

  nF = 1.0
  nI = 1

  # disjoint trees vector
  tv = [sTbd(0.0, false)]

  th = 0.0

  # start simulation
  while true
    w   = cbd_wait(nF, λ, μ)

    # track backward time
    th += w

    if nI > maxn
      return tv[nI], (mxth + 0.1)
    end

    if th > mxth
     return tv[nI], th
    end

    for t in tv
      adde!(t, w)
    end

    # if speciation
    if λorμ(λ, μ)
      if isone(nI)
        return tv[nI], th
      else
        j, k = samp2(Base.OneTo(nI))
        tv[j] = sTbd(tv[j], tv[k], 0.0)
        deleteat!(tv,k)
        nI -= 1
        nF -= 1.0
      end
    # if extinction
    else
      nI += 1
      nF += 1.0
      push!(tv, sTbd(0.0, true))
    end
  end
end




"""
    samp2(o::Base.OneTo{Int64})

Sample `2` without replacement from `o`.
"""
function samp2(o::Base.OneTo{Int64})
  j = rand(o)
  k = rand(o)
  while k == j
    k = rand(o)
  end
  return j, k
end






"""
    cbd_wait(n::Float64, λ::Float64, μ::Float64)

Sample a waiting time for constant birth-death when `n` species
are alive with speciation rate `λ` and extinction rate `μ`.
"""
cbd_wait(n::Float64, λ::Float64, μ::Float64) = rexp(n*(λ + μ))




"""
    cbd_wait(λ::Float64, μ::Float64)

Sample a per-lineage waiting time for constant birth-death species
with speciation rate `λ` and extinction rate `μ`.
"""
cbd_wait(λ::Float64, μ::Float64) = rexp(λ + μ)





"""
    rexp(r::Float64)

Generate an exponential sample with rate `r`.
"""
rexp(r::Float64) = @fastmath randexp()/r




"""
    λorμ(λ::Float64, μ::Float64)

Return `true` if speciation event
"""
λorμ(λ::Float64, μ::Float64) = (λ/(λ + μ)) > rand()

