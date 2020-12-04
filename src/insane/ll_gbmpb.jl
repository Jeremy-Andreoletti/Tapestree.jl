#=

GBM pure-death likelihood

Ignacio Quintero Mächler

t(-_-t)

Created 03 09 2020
=#



"""
    llik_gbm(tree::iTgbmpb, 
             σλ  ::Float64,
             δt  ::Float64
             srδt::Float64)
Returns the log-likelihood for a `iTgbmpb` according to GBM birth-death.
"""
function llik_gbm(tree::iTgbmpb, 
                  σλ  ::Float64,
                  δt  ::Float64,
                  srδt::Float64)

  tsb = ts(tree)
  lλb = lλ(tree)

  if istip(tree) 
    ll_gbm_b(tsb, lλb, σλ, δt, srδt)
  else
    ll_gbm_b(tsb, lλb, σλ, δt, srδt)         +
    log(2.0) + lλb[end]                      +
    llik_gbm(tree.d1::iTgbmpb, σλ, δt, srδt) +
    llik_gbm(tree.d2::iTgbmpb, σλ, δt, srδt)
  end
end




"""
    ll_gbm_b(t   ::Array{Float64,1},
             lλv ::Array{Float64,1},
             σλ  ::Float64, 
             δt  ::Float64,
             srδt::Float64)


Returns the log-likelihood for a branch according to GBM pure-birth.
"""
function ll_gbm_b(t   ::Array{Float64,1},
                  lλv ::Array{Float64,1},
                  σλ  ::Float64, 
                  δt  ::Float64,
                  srδt::Float64)
  @inbounds @fastmath begin

    # estimate standard `δt` likelihood
    nI = lastindex(t)-2

    llbm = 0.0
    llpb = 0.0
    lλvi = lλv[1]
    @simd for i in Base.OneTo(nI)
      lλvi1 = lλv[i+1]
      llbm += (lλvi1 - lλvi)^2
      llpb += exp(0.5*(lλvi + lλvi1))
      lλvi  = lλvi1
    end

    # add to global likelihood
    ll  = llbm*(-0.5/((σλ*srδt)^2)) - Float64(nI)*(log(σλ*srδt) + 0.5*log(2.0π))
    ll -= llpb*δt

    # add final non-standard `δt`
    δtf   = t[nI+2] - t[nI+1]
    lλvi1 = lλv[nI+2]
    ll += ldnorm_bm(lλvi1, lλvi, sqrt(δtf)*σλ)
    ll -= δtf*exp(0.5*(lλvi + lλvi1))
  end

  return ll
end





"""
    llr_gbm_b(t   ::Array{Float64,1},
              lλp ::Array{Float64,1},
              lλc ::Array{Float64,1},
              σλ  ::Float64, 
              δt  ::Float64,
              srδt::Float64)


Returns the log-likelihood ratio for a branch according to GBM pure-birth.
"""
function llr_gbm_b(t   ::Array{Float64,1},
                   lλp ::Array{Float64,1},
                   lλc ::Array{Float64,1},
                   σλ  ::Float64, 
                   δt  ::Float64,
                   srδt::Float64)
  @inbounds @fastmath begin

    # estimate standard `δt` likelihood
    nI = lastindex(t)-2

    llbm = 0.0
    llpb = 0.0
    lλpi = lλp[1]
    lλci = lλc[1]
    @simd for i in Base.OneTo(nI)
      lλpi1 = lλp[i+1]
      lλci1 = lλc[i+1]
      llbm += (lλpi1 - lλpi)^2 - (lλci1 - lλci)^2
      llpb += exp(0.5*(lλpi + lλpi1)) - exp(0.5*(lλci + lλci1))
      lλpi  = lλpi1
      lλci  = lλci1
    end

    # add to global likelihood
    llr  = llbm*(-0.5/((σλ*srδt)^2))
    llr -= δt*llpb

    # add final non-standard `δt`
    δtf   = t[nI+2] - t[nI+1]
    lλpi1 = lλp[nI+2]
    lλci1 = lλc[nI+2]
    llr += lrdnorm_bm_x(lλpi1, lλpi, lλci1, lλci, sqrt(δtf)*σλ)
    llr -= δtf*(exp(0.5*(lλpi + lλpi1)) - exp(0.5*(lλci + lλci1)))
  end

  return llr
end




"""
    ll_gbm_b_sep(t   ::Array{Float64,1},
                 lλv ::Array{Float64,1},
                 σλ  ::Float64, 
                 δt  ::Float64,
                 srδt::Float64)
Returns the log-likelihood for a branch according to GBM pure-birth 
separately for the Brownian motion and the pure-birth
"""
function ll_gbm_b_sep(t   ::Array{Float64,1},
                      lλv ::Array{Float64,1},
                      σλ  ::Float64, 
                      δt  ::Float64,
                      srδt::Float64)
  @inbounds @fastmath begin

    # estimate standard `δt` likelihood
    nI = lastindex(t)-2

    llbm = 0.0
    llpb = 0.0
    lλvi = lλv[1]
    @simd for i in Base.OneTo(nI)
      lλvi1 = lλv[i+1]
      llbm += (lλvi1 - lλvi)^2
      llpb += exp(0.5*(lλvi + lλvi1))
      lλvi  = lλvi1
    end

    # add to global likelihood
    llbm *= (-0.5/((σλ*srδt)^2))
    llbm -= Float64(nI)*(log(σλ*srδt) + 0.5*log(2.0π))
    llpb *= (-δt)

    # add final non-standard `δt`
    δtf   = t[nI+2] - t[nI+1]
    lλvi1 = lλv[nI+2]
    llbm += ldnorm_bm(lλvi1, lλvi, sqrt(δtf)*σλ)
    llpb -= δtf*exp(0.5*(lλvi + lλvi1))
  end

  return llbm, llpb
end




"""
    llr_gbm_b_sep(t   ::Array{Float64,1},
                 lλv ::Array{Float64,1},
                 σλ  ::Float64, 
                 δt  ::Float64,
                 srδt::Float64)
Returns the log-likelihood for a branch according to GBM pure-birth 
separately for the Brownian motion and the pure-birth
"""
function llr_gbm_b_sep(t   ::Array{Float64,1},
                       lλp ::Array{Float64,1},
                       lλc ::Array{Float64,1},
                       σλ  ::Float64, 
                       δt  ::Float64,
                       srδt::Float64)
  @inbounds @fastmath begin

    # estimate standard `δt` likelihood
    nI = lastindex(t)-2

    llrbm = 0.0
    llrpb = 0.0
    lλpi = lλp[1]
    lλci = lλc[1]
    @simd for i in Base.OneTo(nI)
      lλpi1  = lλp[i+1]
      lλci1  = lλc[i+1]
      llrbm += (lλpi1 - lλpi)^2 - (lλci1 - lλci)^2
      llrpb += exp(0.5*(lλpi + lλpi1)) - exp(0.5*(lλci + lλci1))
      lλpi   = lλpi1
      lλci   = lλci1
    end

    # add to global likelihood
    llrbm *= (-0.5/((σλ*srδt)^2))
    llrpb *= (-δt)

    # add final non-standard `δt`
    δtf   = t[nI+2] - t[nI+1]
    lλpi1 = lλp[nI+2]
    lλci1 = lλc[nI+2]
    llrbm += lrdnorm_bm_x(lλpi1, lλpi, lλci1, lλci, sqrt(δtf)*σλ)
    llrpb -= δtf*(exp(0.5*(lλpi + lλpi1)) - exp(0.5*(lλci + lλci1)))
  end

  return llrbm, llrpb
end




"""
    ll_gbm_b_pb(t  ::Array{Float64,1},
                lλv::Array{Float64,1},
                δt ::Float64)
Returns the log-likelihood for a branch according to GBM pure-birth 
separately for the Brownian motion and the pure-birth
"""
function ll_gbm_b_pb(t  ::Array{Float64,1},
                     lλv::Array{Float64,1},
                     δt ::Float64)
  @inbounds @fastmath begin

    # estimate standard `δt` likelihood
    nI = lastindex(t)-2

    ll = 0.0
    lλvi = lλv[1]
    @simd for i in Base.OneTo(nI)
      lλvi1 = lλv[i+1]
      ll   += exp(0.5*(lλvi + lλvi1))
      lλvi  = lλvi1
    end

    # add to global likelihood
    ll *= (-δt)

    # add final non-standard `δt`
    ll -= (t[nI+2] - t[nI+1])*exp(0.5*(lλvi + lλv[nI+2]))
  end

  return ll
end




"""
    llr_gbm_bm(tree::iTgbmpb, 
               σλp  ::Float64,
               σλc  ::Float64,
               srδt::Float64)
Returns the log-likelihood for a `iTgbmpb` according to GBM birth-death.
"""
function llr_gbm_bm(tree::iTgbmpb, 
                    σλp  ::Float64,
                    σλc  ::Float64,
                    srδt::Float64)

  if istip(tree) 
    llr_gbm_bm(ts(tree), lλ(tree), σλp, σλc, srδt)
  else
    llr_gbm_bm(ts(tree), lλ(tree), σλp, σλc, srδt) +
    llr_gbm_bm(tree.d1::iTgbmpb, σλp, σλc, srδt)   +
    llr_gbm_bm(tree.d2::iTgbmpb, σλp, σλc, srδt)
  end
end




"""
    llr_gbm_bm(t   ::Array{Float64,1},
               lλv ::Array{Float64,1},
               σλp  ::Float64, 
               σλc  ::Float64, 
               srδt::Float64)
Returns the log-likelihood ratio for a branch according to BM for `σ` proposal.
"""
function llr_gbm_bm(t   ::Array{Float64,1},
                    lλv ::Array{Float64,1},
                    σλp  ::Float64, 
                    σλc  ::Float64, 
                    srδt::Float64)
  @inbounds @fastmath begin

    # estimate standard `δt` likelihood
    nI = lastindex(t)-2

    ss   = 0.0
    lλvi = lλv[1]
    @simd for i in Base.OneTo(nI)
      lλvi1 = lλv[i+1]
      ss   += (lλvi1 - lλvi)^2
      lλvi  = lλvi1
    end

    # likelihood ratio
    llr = ss*(0.5/((σλc*srδt)^2) - 0.5/((σλp*srδt)^2)) - 
          Float64(nI)*(log(σλp/σλc))

    # add final non-standard `δt`
    srδtf = sqrt(t[nI+2] - t[nI+1])
    lλvi1 = lλv[nI+2]
    llr  += lrdnorm_bm_σ(lλvi1, lλvi, srδtf*σλp, srδtf*σλc)
  end

  return llr
end





