#=

`gbmbd` likelihood

Ignacio Quintero Mächler

t(-_-t)

Created 03 09 2020
=#




"""
    cond_surv_crown(tree::iTgbmbd)

Crown conditioning on survival for `tree`.
"""
cond_surv_crown(tree::iTgbmbd) = 
  sum_alone_stem(tree.d1::iTgbmbd, 0.0, 0.0) + 
  sum_alone_stem(tree.d2::iTgbmbd, 0.0, 0.0) + 
  lλ(tree)[1]





"""
    cond_surv_stem(tree::iTgbmbd)

Stem conditioning on survival for `tree`.
"""
cond_surv_stem(tree::iTgbmbd) = 
  sum_alone_stem(tree, 0.0, 0.0)




"""
    sum_alone_stem(tree::iTgbmbd, tna::Float64, ll::Float64)

Condition events when there is only one alive lineage to only be 
speciation events.
"""
function sum_alone_stem(tree::iTgbmbd, tna::Float64, ll::Float64)

  if istip(tree)
    return ll
  end

  if tna < e(tree)
    @inbounds begin
      lλv = lλ(tree)
      lv  = lastindex(lλv)
      λi  = lλv[lv]
      μi  = lμ(tree)[lv]
    end
    @fastmath ll += log(exp(λi) + exp(μi)) - λi
  end
  tna -= e(tree)

  if isfix(tree.d1)
    if isfix(tree.d2)
      return ll
    else
      tnx = treeheight(tree.d2)
      tna = tnx > tna ? tnx : tna
      sum_alone_stem(tree.d1, tna, ll)
    end
  else
    tnx = treeheight(tree.d1)
    tna = tnx > tna ? tnx : tna
    sum_alone_stem(tree.d2, tna, ll)
  end
end




"""
    cond_surv_stem_p(tree::iTgbmbd)

Stem conditioning on survival for `tree`.
"""
cond_surv_stem_p(tree::iTgbmbd) = 
  sum_alone_stem_p(tree, 0.0, 0.0)




"""
    sum_alone_stem(tree::iTgbmbd, tna::Float64, ll::Float64)

Condition events when there is only one alive lineage to only be 
speciation events.
"""
function sum_alone_stem_p(tree::iTgbmbd, tna::Float64, ll::Float64)

  if tna < e(tree)
    @inbounds begin
      lλv = lλ(tree)
      lv  = lastindex(lλv)
      λi  = lλv[lv]
      μi  = lμ(tree)[lv]
    end
    @fastmath ll += log(exp(λi) + exp(μi)) - λi
  end
  tna -= e(tree)

  if istip(tree)
    return ll
  end

  if isfix(tree.d1)
    if isfix(tree.d2)
      return ll
    else
      tnx = treeheight(tree.d2)
      tna = tnx > tna ? tnx : tna
      sum_alone_stem_p(tree.d1, tna, ll)
    end
  else
    tnx = treeheight(tree.d1)
    tna = tnx > tna ? tnx : tna
    sum_alone_stem_p(tree.d2, tna, ll)
  end
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
    sss_gbm(tree::iTgbmbd, α::Float64)

Returns the log-likelihood ratio for a `iTgbmbd` according 
to `gbmbd` for a `σ` proposal.
"""
function sss_gbm(tree::iTgbmbd, α::Float64)

  ssλ, ssμ, n = 
    sss_gbm_b(lλ(tree), lμ(tree), α, dt(tree), fdt(tree))

  if isdefined(tree, :d1) 
    ssλ1, ssμ1, n1 = sss_gbm(tree.d1, α)
    ssλ2, ssμ2, n2 = sss_gbm(tree.d2, α)

    ssλ += ssλ1 + ssλ2
    ssμ += ssμ1 + ssμ2
    n   += n1 + n2
  end

  return ssλ, ssμ, n
end




"""
    sss_gbm_b(lλv::Array{Float64,1},
              lμv::Array{Float64,1},
              δt ::Float64, 
              fdt::Float64)

Returns the standardized sum of squares for the GBM part of a branch 
for `gbmbd`.
"""
@inline function sss_gbm_b(lλv::Array{Float64,1},
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
    llik_gbm_f(tree::iTgbmbd,
               α   ::Float64,
               σλ  ::Float64,
               σμ  ::Float64,
               δt  ::Float64,
               srδt::Float64)

Estimate `gbmbd` likelihood for the tree in a fix branch.
"""
function llik_gbm_f(tree::iTgbmbd,
                    α   ::Float64,
                    σλ  ::Float64,
                    σμ  ::Float64,
                    δt  ::Float64,
                    srδt::Float64)

  if istip(tree)
    ll = ll_gbm_b(lλ(tree), lμ(tree), 
           α, σλ, σμ, δt, fdt(tree), srδt, false, false)
  else
    ll = ll_gbm_b(lλ(tree), lμ(tree), 
           α, σλ, σμ, δt, fdt(tree), srδt, true, false)

    ifx1 = isfix(tree.d1)
    if ifx1 && isfix(tree.d2)
      return ll
    elseif ifx1
      ll += llik_gbm_f(tree.d1, α, σλ, σμ, δt, srδt) +
            llik_gbm(  tree.d2, α, σλ, σμ, δt, srδt)
    else
      ll += llik_gbm(  tree.d1, α, σλ, σμ, δt, srδt) + 
            llik_gbm_f(tree.d2, α, σλ, σμ, δt, srδt)
    end
  end

  return ll
end




"""
    br_ll_gbm(tree::iTgbmbd,
              α   ::Float64,
              σλ  ::Float64,
              σμ  ::Float64,
              δt  ::Float64,
              srδt::Float64,
              dri ::BitArray{1},
              ldr ::Int64,
              ix  ::Int64)

Returns `gbmbd` likelihood for whole branch `br`.
"""
function br_ll_gbm(tree::iTgbmbd,
                   α   ::Float64,
                   σλ  ::Float64,
                   σμ  ::Float64,
                   δt  ::Float64,
                   srδt::Float64,
                   dri ::BitArray{1},
                   ldr ::Int64,
                   ix  ::Int64)

  if ix === ldr
    return llik_gbm_f(tree, α, σλ, σμ, δt, srδt)
  elseif ix < ldr
    ifx1 = isfix(tree.d1)
    if ifx1 && isfix(tree.d2)
      ix += 1
      if dri[ix]
        ll = br_ll_gbm(tree.d1, α, σλ, σμ, δt, srδt, dri, ldr, ix)
      else
        ll = br_ll_gbm(tree.d2, α, σλ, σμ, δt, srδt, dri, ldr, ix)
      end
    elseif ifx1
      ll = br_ll_gbm(tree.d1, α, σλ, σμ, δt, srδt, dri, ldr, ix)
    else
      ll = br_ll_gbm(tree.d2, α, σλ, σμ, δt, srδt, dri, ldr, ix)
    end
  end

  return ll
end





"""
    llr_gbm_sep_f(treep::iTgbmbd,
                  treec::iTgbmbd,
                  α    ::Float64,
                  σλ  ::Float64,
                  σμ  ::Float64,
                  δt  ::Float64,
                  srδt::Float64)

Returns the log-likelihood for a branch according to `gbmbd` 
separately (for gbm and bd).
"""
function llr_gbm_sep_f(treep::iTgbmbd,
                       treec::iTgbmbd,
                       α    ::Float64,
                       σλ  ::Float64,
                       σμ  ::Float64,
                       δt  ::Float64,
                       srδt::Float64)

  if istip(treec)
    llrbm, llrbd = 
      llr_gbm_b_sep(lλ(treep), lμ(treep), lλ(treec), lμ(treec), α, σλ, σμ, δt, 
        fdt(treec), srδt, false, isextinct(treec))
  else
    llrbm, llrbd = 
      llr_gbm_b_sep(lλ(treep), lμ(treep), lλ(treec), lμ(treec), α, σλ, σμ, δt, 
        fdt(treec), srδt, true, false) 

    ifx1 = isfix(treec.d1)
    if ifx1 && isfix(treec.d2)
      return llrbm, llrbd
    elseif ifx1
      llrbm0, llrbd0 = llr_gbm_sep_f(treep.d1, treec.d1, α, σλ, σμ, δt, srδt)
      llrbm1, llrbd1 = llr_gbm_sep(  treep.d2, treec.d2, α, σλ, σμ, δt, srδt)
      llrbm += llrbm0 + llrbm1
      llrbd += llrbd0 + llrbd1
    else
      llrbm0, llrbd0 = llr_gbm_sep(  treep.d1, treec.d1, α, σλ, σμ, δt, srδt)
      llrbm1, llrbd1 = llr_gbm_sep_f(treep.d2, treec.d2, α, σλ, σμ, δt, srδt)
      llrbm += llrbm0 + llrbm1
      llrbd += llrbd0 + llrbd1
    end
  end

  return llrbm, llrbd
end




"""
    llr_gbm_sep(treep::iTgbmbd, 
                treec::iTgbmbd,
                α    ::Float64,
                σλ   ::Float64,
                σμ   ::Float64,
                δt   ::Float64,
                srδt ::Float64)

Returns the log-likelihood ratio for a tree according to `gbmbd` 
separately (for gbm and bd).
"""
function llr_gbm_sep(treep::iTgbmbd, 
                     treec::iTgbmbd,
                     α    ::Float64,
                     σλ   ::Float64,
                     σμ   ::Float64,
                     δt   ::Float64,
                     srδt ::Float64)

  if istip(treec) 
    llrbm, llrbd = 
      llr_gbm_b_sep(lλ(treep), lμ(treep), lλ(treec), lμ(treec), α, σλ, σμ, δt, 
        fdt(treec), srδt, false, isextinct(treec))
  else
    llrbm, llrbd = 
      llr_gbm_b_sep(lλ(treep), lμ(treep), lλ(treec), lμ(treec), α, σλ, σμ, δt, 
        fdt(treec), srδt, true, false) 

    llrbm0, llrbd0 = llr_gbm_sep(treep.d1, treec.d1, α, σλ, σμ, δt, srδt) 
    llrbm1, llrbd1 = llr_gbm_sep(treep.d2, treec.d2, α, σλ, σμ, δt, srδt)

    llrbm += llrbm0 + llrbm1
    llrbd += llrbd0 + llrbd1
  end
  
  return llrbm, llrbd
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
                  fdt::Float64,
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
                       fdt::Float64,
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

  return llrbm, llrbd
end





