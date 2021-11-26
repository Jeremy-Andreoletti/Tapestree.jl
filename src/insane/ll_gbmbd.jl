#=

`gbmbd` likelihood

Ignacio Quintero Mächler

t(-_-t)

Created 03 09 2020
=#




"""
    llik_cbd(psi::Vector{iTgbmbd}, 
             idf::Vector{iBffs},
             α   ::Float64,
             σλ  ::Float64,
             μ   ::Float64, 
             δt  ::Float64,
             srδt::Float64,
             scond::Function)

Returns the log-likelihood for a `iTgbmbd` according to `gbm-bd`.
"""
function llik_gbm(psi::Vector{iTgbmbd}, 
                  idf::Vector{iBffs},
                  α   ::Float64,
                  σλ  ::Float64,
                  σμ   ::Float64, 
                  δt  ::Float64,
                  srδt::Float64)
  @inbounds begin
    ll = 0.0
    for i in Base.OneTo(lastindex(psi))
      bi  = idf[i]
      ll += llik_gbm(psi[i], α, σλ, σμ, δt, srδt)
      if !it(bi)
        ll += λt(bi)
      end
    end
  end

  return ll
end




"""
    llik_gbm(tree::iTgbmbd, 
             α   ::Float64,
             σλ  ::Float64, 
             σμ  ::Float64,
             δt  ::Float64,
             srδt::Float64)

Returns the log-likelihood for a `iTgbmbd` according to `gbmbd`.
"""
function llik_gbm(tree::iTgbmbd, 
                  α   ::Float64,
                  σλ  ::Float64, 
                  σμ  ::Float64,
                  δt  ::Float64,
                  srδt::Float64)

  if istip(tree) 
    ll_gbm_b(lλ(tree), lμ(tree), α, σλ, σμ, δt, fdt(tree), srδt, 
      false, isextinct(tree))
  else
    ll_gbm_b(lλ(tree), lμ(tree), α, σλ, σμ, δt, fdt(tree), srδt, true, false) +
    llik_gbm(tree.d1, α, σλ, σμ, δt, srδt)                                    +
    llik_gbm(tree.d2, α, σλ, σμ, δt, srδt)
  end
end





"""
    ll_gbm_b(lλv ::Array{Float64,1},
             lμv ::Array{Float64,1},
             α   ::Float64,
             σλ  ::Float64,
             σμ  ::Float64,
             δt  ::Float64, 
             fdt ::Float64,
             srδt::Float64,
             λev ::Bool,
             μev ::Bool)

Returns the log-likelihood for a branch according to `gbmbd`.
"""
@inline function ll_gbm_b(lλv ::Array{Float64,1},
                          lμv ::Array{Float64,1},
                          α   ::Float64,
                          σλ  ::Float64,
                          σμ  ::Float64,
                          δt  ::Float64, 
                          fdt ::Float64,
                          srδt::Float64,
                          λev ::Bool,
                          μev ::Bool)

  @inbounds begin

    # estimate standard `δt` likelihood
    nI = lastindex(lλv)-2

    llλ  = 0.0
    llμ  = 0.0
    llbd = 0.0
    lλvi = lλv[1]
    lμvi = lμv[1]
    @simd for i in Base.OneTo(nI)
      lλvi1 = lλv[i+1]
      lμvi1 = lμv[i+1]
      llλ  += (lλvi1 - lλvi - α*δt)^2
      llμ  += (lμvi1 - lμvi)^2
      llbd += exp(0.5*(lλvi + lλvi1)) + exp(0.5*(lμvi + lμvi1)) 
      lλvi  = lλvi1
      lμvi  = lμvi1
    end

    # add to global likelihood
    ll = llλ*(-0.5/((σλ*srδt)^2)) - Float64(nI)*(log(σλ*srδt) + 0.5*log(2.0π)) + 
         llμ*(-0.5/((σμ*srδt)^2)) - Float64(nI)*(log(σμ*srδt) + 0.5*log(2.0π))
    # add to global likelihood
    ll -= llbd*δt

    lλvi1 = lλv[nI+2]
    lμvi1 = lμv[nI+2]

    # add final non-standard `δt`
    if fdt > 0.0
      srfdt = sqrt(fdt)
      ll += ldnorm_bm(lλvi1, lλvi + α*fdt, srfdt*σλ)
      ll += ldnorm_bm(lμvi1, lμvi, srfdt*σμ)
      ll -= fdt*(exp(0.5*(lλvi + lλvi1)) + exp(0.5*(lμvi + lμvi1)))
    end

    #if speciation
    if λev
      ll += lλvi1
    end
    #if extinction
    if μev
      ll += lμvi1
    end
  end

  return ll
end




"""
    llik_gbm_ss(tree::iTgbmbd,
                α   ::Float64, 
                σλ  ::Float64, 
                ϵ   ::Float64,
                δt  ::Float64,
                srδt::Float64)

Returns the log-likelihood for a `iTgbmbd` according to `gbmbd`.
"""
function llik_gbm_ss(tree::iTgbmbd,
                     α   ::Float64, 
                     σλ  ::Float64, 
                     σμ  ::Float64,
                     δt  ::Float64,
                     srδt::Float64)

  if istip(tree)
    ll, dλ, ssλ, ssμ, nλ = 
      ll_gbm_b_ss(lλ(tree), lμ(tree), α, σλ, σμ, δt, fdt(tree), srδt, 
        false, isextinct(tree))
  else
    ll, dλ, ssλ, ssμ, nλ = 
      ll_gbm_b_ss(lλ(tree), lμ(tree), α, σλ, σμ, δt, fdt(tree), srδt, 
        true, false)

    ll1, dλ1, ssλ1, ssμ1, nλ1 = 
      llik_gbm_ss(tree.d1, α, σλ, σμ, δt, srδt)
    ll2, dλ2, ssλ2, ssμ2, nλ2 = 
      llik_gbm_ss(tree.d2, α, σλ, σμ, δt, srδt)

    ll  += ll1  + ll2
    dλ  += dλ1  + dλ2
    ssλ += ssλ1 + ssλ2
    ssμ += ssμ1 + ssμ2
    nλ  += nλ1  + nλ2
  end

  return ll, dλ, ssλ, ssμ, nλ
end




"""
    ll_gbm_b_ss(lλv ::Array{Float64,1},
                lμv ::Array{Float64,1},
                α   ::Float64,
                σλ  ::Float64,
                σμ  ::Float64,
                δt  ::Float64, 
                fdt ::Float64,
                srδt::Float64,
                λev ::Bool,
                μev ::Bool)

Returns the log-likelihood for a branch according to `gbmbd`.
"""
@inline function ll_gbm_b_ss(lλv ::Array{Float64,1},
                             lμv ::Array{Float64,1},
                             α   ::Float64,
                             σλ  ::Float64,
                             σμ  ::Float64,
                             δt  ::Float64, 
                             fdt ::Float64,
                             srδt::Float64,
                             λev ::Bool,
                             μev ::Bool)

  @inbounds begin

    # estimate standard `δt` likelihood
    nI = lastindex(lλv)-2

    llλ  = 0.0
    llμ  = 0.0
    llbd = 0.0
    lλvi = lλv[1]
    lμvi = lμv[1]
    @simd for i in Base.OneTo(nI)
      lλvi1 = lλv[i+1]
      lμvi1 = lμv[i+1]
      llλ  += (lλvi1 - lλvi - α*δt)^2
      llμ  += (lμvi1 - lμvi)^2
      llbd += exp(0.5*(lλvi + lλvi1)) + exp(0.5*(lμvi + lμvi1)) 
      lλvi  = lλvi1
      lμvi  = lμvi1
    end

    # standardized sum of squares
    ssλ = llλ/(2.0*δt)
    ssμ = llμ/(2.0*δt)
    nλ  = Float64(nI)

    # add to global likelihood
    ll = llλ*(-0.5/((σλ*srδt)^2)) - Float64(nI)*(log(σλ*srδt) + 0.5*log(2.0π)) + 
         llμ*(-0.5/((σμ*srδt)^2)) - Float64(nI)*(log(σμ*srδt) + 0.5*log(2.0π))
    # add to global likelihood
    ll -= llbd*δt

    lλvi1 = lλv[nI+2]
    lμvi1 = lμv[nI+2]

    dλ = lλvi1 - lλv[1]

    # add final non-standard `δt`
    if fdt > 0.0
      srfdt = sqrt(fdt)
      ll  += ldnorm_bm(lλvi1, lλvi + α*fdt, srfdt*σλ)
      ll  += ldnorm_bm(lμvi1, lμvi, srfdt*σμ)
      ll  -= fdt*(exp(0.5*(lλvi + lλvi1)) + exp(0.5*(lμvi + lμvi1)))
      ssλ += (lλvi1 - lλvi - α*fdt)^2/(2.0*fdt)
      ssμ += (lμvi1 - lμvi)^2/(2.0*fdt)
      nλ  += 1.0
    end

    #if speciation
    if λev
      ll += lλvi1
    end
    #if extinction
    if μev
      ll += lμvi1
    end
  end

  return ll, dλ, ssλ, ssμ, nλ
end







"""
    _sss_gbm(tree::iTgbmbd, 
             α   ::Float64, 
             ssλ ::Float64, 
             ssμ ::Float64, 
             n   ::Float64)

Returns the standardized sum of squares a `iTgbm` according 
to `gbm-bd` for a `σ` proposal.
"""
function _sss_gbm(tree::iTgbmbd, 
                  α   ::Float64, 
                  ssλ ::Float64, 
                  ssμ ::Float64, 
                  n   ::Float64)

  ssλ0, ssμ0, n0 = _sss_gbm_b(lλ(tree), lμ(tree), α, dt(tree), fdt(tree))

  ssλ += ssλ0
  ssμ += ssμ0
  n   += n0

  if isdefined(tree, :d1) 
    ssλ, ssμ, n = _sss_gbm(tree.d1, α, ssλ, ssμ, n)
    ssλ, ssμ, n = _sss_gbm(tree.d2, α, ssλ, ssμ, n)
  end

  return ssλ, ssμ, n
end




"""
    _sss_gbm_b(lλv::Array{Float64,1},
               lμv::Array{Float64,1},
               α  ::Float64,
               δt ::Float64, 
               fdt::Float64)

Returns the standardized sum of squares for the GBM part of a branch 
for `gbmbd`.
"""
@inline function _sss_gbm_b(lλv::Array{Float64,1},
                            lμv::Array{Float64,1},
                            α  ::Float64,
                            δt ::Float64, 
                            fdt::Float64)

  @inbounds begin

    # estimate standard `δt` likelihood
    nI = lastindex(lλv)-2

    ssλ  = 0.0
    ssμ  = 0.0
    lλvi = lλv[1]
    lμvi = lμv[1]
    @simd for i in Base.OneTo(nI)
      lλvi1 = lλv[i+1]
      lμvi1 = lμv[i+1]
      ssλ  += (lλvi1 - lλvi - α*δt)^2
      ssμ  += (lμvi1 - lμvi)^2
      lλvi  = lλvi1
      lμvi  = lμvi1
    end

    # add to global likelihood
    invt = 1.0/(2.0*δt)
    ssλ *= invt
    ssμ *= invt

    # add final non-standard `δt`
    if fdt > 0.0
      invt = 1.0/(2.0*fdt)
      ssλ += invt * (lλv[nI+2] - lλvi - α*fdt)^2
      ssμ += invt * (lμv[nI+2] - lμvi)^2
      n = Float64(nI + 1)
    else
      n = Float64(nI)
    end
  end

  return ssλ, ssμ, n
end







"""
    llr_gbm_b_sep(lλp ::Array{Float64,1},
                  lμp ::Array{Float64,1},
                  lλc ::Array{Float64,1},
                  lμc ::Array{Float64,1},
                  α   ::Float64,
                  σλ  ::Float64,
                  σμ  ::Float64,
                  δt  ::Float64, 
                  fdt ::Float64,
                  srδt::Float64,
                  λev ::Bool,
                  μev ::Bool)

Returns the log-likelihood for a branch according to `gbmbd` 
separately (for gbm and bd).
"""
function llr_gbm_b_sep(lλp ::Array{Float64,1},
                       lμp ::Array{Float64,1},
                       lλc ::Array{Float64,1},
                       lμc ::Array{Float64,1},
                       α   ::Float64,
                       σλ  ::Float64,
                       σμ  ::Float64,
                       δt  ::Float64, 
                       fdt ::Float64,
                       srδt::Float64,
                       λev ::Bool,
                       μev ::Bool)

  @inbounds @fastmath begin

    # estimate standard `δt` likelihood
    nI = lastindex(lλc)-2

    llrbmλ = 0.0
    llrbmμ = 0.0
    llrbd  = 0.0
 
    lλpi = lλp[1]
    lλci = lλc[1]
    lμpi = lμp[1]
    lμci = lμc[1]

    @simd for i in Base.OneTo(nI)
      lλpi1   = lλp[i+1]
      lλci1   = lλc[i+1]
      lμpi1   = lμp[i+1]
      lμci1   = lμc[i+1]
      llrbmλ += (lλpi1 - lλpi - α*δt)^2 - (lλci1 - lλci - α*δt)^2
      llrbmμ += (lμpi1 - lμpi)^2 - (lμci1 - lμci)^2
      llrbd  += exp(0.5*(lλpi + lλpi1)) - exp(0.5*(lλci + lλci1)) +
                exp(0.5*(lμpi + lμpi1)) - exp(0.5*(lμci + lμci1))
      lλpi    = lλpi1
      lλci    = lλci1
      lμpi    = lμpi1
      lμci    = lμci1
    end

    # standardized sum of squares
    ssrλ = llrbmλ/(2.0*δt)
    ssrμ = llrbmμ/(2.0*δt)

    # overall
    llrbmλ *= (-0.5/((σλ*srδt)^2))
    llrbmμ *= (-0.5/((σμ*srδt)^2))
    llrbd  *= (-δt)
    llrbm   = llrbmλ + llrbmμ

    lλpi1 = lλp[nI+2]
    lμpi1 = lμp[nI+2]
    lλci1 = lλc[nI+2]
    lμci1 = lμc[nI+2]

    # add final non-standard `δt`
    if fdt > 0.0
      ssrλ  += ((lλpi1 - lλpi - α*fdt)^2 - (lλci1 - lλci - α*fdt)^2)/(2.0*fdt)
      ssrμ  += ((lμpi1 - lμpi)^2 - (lμci1 - lμci)^2)/(2.0*fdt)
      srfdt = sqrt(fdt)
      llrbm += lrdnorm_bm_x(lλpi1, lλpi + α*fdt, 
                            lλci1, lλci + α*fdt, srfdt*σλ) +
               lrdnorm_bm_x(lμpi1, lμpi, lμci1, lμci, srfdt*σμ)
      llrbd -= fdt*(exp(0.5*(lλpi + lλpi1)) - exp(0.5*(lλci + lλci1)) +
                    exp(0.5*(lμpi + lμpi1)) - exp(0.5*(lμci + lμci1)))
    end

    if λev
      llrbd += lλpi1 - lλci1 
    end
    if μev
      llrbd += lμpi1 - lμci1 
    end
  end

  return llrbm, llrbd, ssrλ, ssrμ
end





"""
    make_scond(idf::Vector{iBffs}, stem::Bool, ::Type{iTgbmbd})

Return closure for log-likelihood for conditioning
"""
function make_scond(idf::Vector{iBffs}, stem::Bool, ::Type{iTgbmbd})

  b1  = idf[1]
  d1i = d1(b1)
  d2i = d2(b1)

  if stem
    # for whole likelihood
    f = let d1i = d1i, d2i = d2i
      function (psi::Vector{iTgbmbd}, sns::NTuple{3,BitVector})
        sn1 = sns[1]
        cond_ll(psi[1], 0.0, sn1, lastindex(sn1), 1)
      end
    end
    # for new proposal
    f0 = (psi::iTgbmbd, ter::Bool) -> 
            sum_alone_stem_p(psi, 0.0, false, 0.0)
  else
    # for whole likelihood
    f = let d1i = d1i, d2i = d2i
      function (psi::Vector{iTgbmbd}, sns::NTuple{3,BitVector})

        sn2 = sns[2]
        sn3 = sns[3]

        cond_ll(psi[d1i], 0.0, sn2, lastindex(sn2), 1) +
        cond_ll(psi[d2i], 0.0, sn3, lastindex(sn3), 1) - lλ(psi[1])[1]
      end
    end
    # for new proposal
    f0 = function (psi::iTgbmbd, ter::Bool)
      if ter
        sum_alone_stem(  psi, 0.0, false, 0.0)
      else
        sum_alone_stem_p(psi, 0.0, false, 0.0)
      end
    end
  end

  return f, f0
end




"""
    cond_ll(tree::iTgbmbd,
            ll  ::Float64, 
            sn  ::BitVector,
            lsn ::Int64,
            ix  ::Int64)

Condition events when there is only one alive lineage in the crown subtrees 
to only be speciation events.
"""
function cond_ll(tree::iTgbmbd,
                 ll  ::Float64, 
                 sn  ::BitVector,
                 lsn ::Int64,
                 ix  ::Int64)

  if lsn >= ix
    if sn[ix]
      λv  = lλ(tree)
      l   = lastindex(λv)
      λi  = λv[l]
      μi  = lμ(tree)[l]
      ll += log(exp(λi) + exp(μi)) - λi
    end

    if lsn === ix
      return ll
    else
      ix += 1
      if isfix(tree.d1::iTgbmbd)
        ll = cond_ll(tree.d1::iTgbmbd, ll, sn, lsn, ix)
      else
        ll = cond_ll(tree.d2::iTgbmbd, ll, sn, lsn, ix)
      end
    end
  end

  return ll
end
