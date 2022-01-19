#=

decoupled tree utilities

Ignacio Quintero Mächler

t(-_-t)

Created 05 11 2020
=#




"""
    sTpb!(Ξ::Vector{sTpb}, tree::sT_label)

Make edge tree `Ξ` from the recursive tree.
"""
function sTpb!(Ξ::Vector{sTpb}, tree::sT_label)

  push!(Ξ, sTpb(e(tree), true))
  if isdefined(tree, :d1)
    sTpb!(Ξ, tree.d2)
    sTpb!(Ξ, tree.d1)
  end
end



"""
    sTbd!(Ξ::Vector{sTbd}, tree::sT_label)

Make edge tree `Ξ` from the recursive tree.
"""
function sTbd!(Ξ::Vector{sTbd}, tree::sT_label)

  push!(Ξ, sTbd(e(tree), false, true))
  if isdefined(tree, :d1)
    sTbd!(Ξ, tree.d2)
    sTbd!(Ξ, tree.d1)
  end
end



"""
    sTfbd!(Ξ::Vector{sTfbd}, tree::sTf_label)

Make edge tree `Ξ` from the recursive tree.
"""
function sTfbd!(Ξ::Vector{sTfbd}, tree::sTf_label)
  defd1 = isdefined(tree, :d1)
  defd2 = isdefined(tree, :d2)
  
  push!(Ξ, sTfbd(e(tree), isextinct(tree), (defd1 && !defd2) || (!defd1 && defd2), true))
  
  if defd2 sTfbd!(Ξ, tree.d2) end
  if defd1 sTfbd!(Ξ, tree.d1) end
end




"""
    make_Ξ(idf::Vector{iBffs}, ::Type{sTbd})

Make edge tree `Ξ` from the edge directory.
"""
function make_Ξ(idf::Vector{iBffs}, ::Type{sTbd})
  Ξ = sTbd[]
  for i in Base.OneTo(lastindex(idf))
    ξ = sTbd(e(idf[i]), false, true)
    push!(Ξ, ξ)
  end
  return Ξ
end




"""
    make_Ξ(idf::Vector{iBfffs}, ::Type{sTfbd})

Make edge tree `Ξ` from the edge directory.
"""
function make_Ξ(idf::Vector{iBfffs}, ::Type{sTfbd})
  Ξ = sTfbd[]
  for i in Base.OneTo(lastindex(idf))
    bi = idf[i]
    ξ = sTfbd(e(bi), ie(bi), ifos(bi), true)
    push!(Ξ, ξ)
  end
  return Ξ
end




"""
    iTgbmpb!(Ξ   ::Vector{iTgbmpb},
             tree::sT_label,
             δt  ::Float64, 
             srδt::Float64, 
             lλa ::Float64,
             α   ::Float64,
             σλ  ::Float64)

Make edge tree `Ξ` from the recursive tree.
"""
function iTgbmpb!(Ξ   ::Vector{iTgbmpb},
                  tree::sT_label,
                  δt  ::Float64, 
                  srδt::Float64, 
                  lλa ::Float64,
                  α   ::Float64,
                  σλ  ::Float64)

  et = e(tree)

  if iszero(et)
    lλv  = Float64[lλa, lλa]
    fdti = 0.0
    l    = 2
  else
    nt, fdti = divrem(et, δt, RoundDown)
    nt = Int64(nt)

    if iszero(fdti)
      fdti = δt
    end
    lλv = sim_bm(lλa, α, σλ, δt, fdti, srδt, nt)
    l   = lastindex(lλv)
  end

  push!(Ξ, iTgbmpb(et, true, δt, fdti, lλv))
  if isdefined(tree, :d1)
    iTgbmpb!(Ξ, tree.d2, δt, srδt, lλv[l], α, σλ) 
    iTgbmpb!(Ξ, tree.d1, δt, srδt, lλv[l], α, σλ)
  end
end





"""
    iTgbmce!(Ξ   ::Vector{iTgbmce},
             tree::sT_label,
             δt  ::Float64, 
             srδt::Float64, 
             lλa ::Float64,
             α   ::Float64,
             σλ  ::Float64)

Make edge tree `Ξ` from the recursive tree.
"""
function iTgbmce!(Ξ   ::Vector{iTgbmce},
                  tree::sT_label,
                  δt  ::Float64, 
                  srδt::Float64, 
                  lλa ::Float64,
                  α   ::Float64,
                  σλ  ::Float64)

  et = e(tree)

  if iszero(et)
    lλv  = Float64[lλa, lλa]
    fdti = 0.0
    l    = 2
  else
    nt, fdti = divrem(et, δt, RoundDown)
    nt = Int64(nt)

    if iszero(fdti)
      fdti = δt
    end
    lλv = sim_bm(lλa, α, σλ, δt, fdti, srδt, nt)
    l   = lastindex(lλv)
  end

  push!(Ξ, iTgbmce(et, δt, fdti, false, true, lλv))
  if isdefined(tree, :d1)
    iTgbmce!(Ξ, tree.d2, δt, srδt, lλv[l], α, σλ) 
    iTgbmce!(Ξ, tree.d1, δt, srδt, lλv[l], α, σλ)
  end
end




"""
    iTgbmct!(Ξ   ::Vector{iTgbmct},
             tree::sT_label,
             δt  ::Float64, 
             srδt::Float64, 
             lλa ::Float64,
             α   ::Float64,
             σλ  ::Float64)

Make edge tree `Ξ` from the recursive tree.
"""
function iTgbmct!(Ξ   ::Vector{iTgbmct},
                  tree::sT_label,
                  δt  ::Float64, 
                  srδt::Float64, 
                  lλa ::Float64,
                  α   ::Float64,
                  σλ  ::Float64)

  et = e(tree)

  if iszero(et)
    lλv  = Float64[lλa, lλa]
    fdti = 0.0
    l    = 2
  else
    nt, fdti = divrem(et, δt, RoundDown)
    nt = Int64(nt)

    if iszero(fdti)
      fdti = δt
    end
    lλv = sim_bm(lλa, α, σλ, δt, fdti, srδt, nt)
    l   = lastindex(lλv)
  end

  push!(Ξ, iTgbmct(et, δt, fdti, false, true, lλv))
  if isdefined(tree, :d1)
    iTgbmct!(Ξ, tree.d2, δt, srδt, lλv[l], α, σλ) 
    iTgbmct!(Ξ, tree.d1, δt, srδt, lλv[l], α, σλ)
  end
end




"""
    iTgbmbd!(Ξ   ::Vector{iTgbmbd},
             tree::sT_label,
             δt  ::Float64, 
             srδt::Float64, 
             lλa ::Float64,
             lμa ::Float64,
             α   ::Float64,
             σλ  ::Float64,
             σμ  ::Float64)

Make edge tree `Ξ` from the recursive tree.
"""
function iTgbmbd!(Ξ   ::Vector{iTgbmbd},
                  tree::sT_label,
                  δt  ::Float64, 
                  srδt::Float64, 
                  lλa ::Float64,
                  lμa ::Float64,
                  α   ::Float64,
                  σλ  ::Float64,
                  σμ  ::Float64)

  et = e(tree)

  if iszero(et)
    lλv  = Float64[lλa, lλa]
    lμv  = Float64[lμa, lμa]
    fdti = 0.0
    l    = 2
  else
    nt, fdti = divrem(et, δt, RoundDown)
    nt = Int64(nt)

    if iszero(fdti)
      fdti = δt
    end
    lλv = sim_bm(lλa, α, σλ, δt, fdti, srδt, nt)
    lμv = sim_bm(lμa, α, σμ, δt, fdti, srδt, nt)
    l   = nt + 2
  end

  push!(Ξ, iTgbmbd(et, δt, fdti, false, true, lλv, lμv))
  if isdefined(tree, :d1)
    iTgbmbd!(Ξ, tree.d2, δt, srδt, lλv[l], lμv[l], α, σλ, σμ)
    iTgbmbd!(Ξ, tree.d1, δt, srδt, lλv[l], lμv[l], α, σλ, σμ)
  end
end




"""
    couple(xi::Vector{T},
           idf::Vector{iBffs},
           ix ::Int64) where {T <: iTree}

Build tree from decoupled tree.
"""
function couple(xi::Vector{T},
                idf::Vector{iBffs},
                ix ::Int64) where {T <: iTree}

  bi = idf[ix]
  ξi = xi[ix]
  if !it(bi)
    ξit = fixtip(ξi)
    ξit.d1 = couple(xi, idf, d1(bi))
    ξit.d2 = couple(xi, idf, d2(bi))
  end

  return ξi
end




"""
    treelength(xi::Vector{T}) where {T<: iTree}

Return the branch length sum of `Ξ`.
"""
function treelength(xi::Vector{T}) where {T<: iTree}
  L = 0.0
  for ξ in xi
    L += _treelength(ξ, 0.0)
  end
  return L
end





"""
    _ctl(tree::Vector{T}) where {T <: iTgbm}

Return the branch length sum of `tree` based on `δt` and `fδt` 
for debugging purposes.
"""
function _ctl(tree::Vector{T}) where {T <: iTgbm}

  L = 0.0
  for ξ in xi
    L += _ctl(ξ, 0.0)
  end
  return L
end




"""
    nnodesinternal(xi::Vector{T}) where {T<: iTree}

Return the internal nodes of `Ξ`.
"""
function nnodesinternal(xi::Vector{T}) where {T<: iTree}
  n = 0
  for ξ in xi
    n += _nnodesinternal(ξ, 0)
  end
  n += Float64(lastindex(xi) - 1)/2.0

  return n
end




"""
    ntipsextinct(xi::Vector{T}) where {T<: iTree}

Return the internal nodes of `Ξ`.
"""
function ntipsextinct(xi::Vector{T}) where {T<: iTree}
  n = 0
  for ξ in xi
    n += _ntipsextinct(ξ, 0)
  end
  return n
end





"""
    sss_gbm(xi::Vector{T}, α::Float64) where {T <: iTgbm}

Returns the standardized sum of squares a `iTgbm` according 
to GBM birth-death for a `σ` proposal.
"""
function sss_gbm(xi::Vector{T}, α::Float64) where {T <: iTgbm}

  n   = 0.0
  ssλ = 0.0
  for ξi in xi
    ssλ, n = _sss_gbm(ξi, α, ssλ, n)
  end

  return ssλ, n
end





"""
    sss_gbm(xi::Vector{iTgbmbd}, α::Float64)

Returns the standardized sum of squares a `iTgbm` according 
to GBM birth-death for a `σ` proposal.
"""
function sss_gbm(xi::Vector{iTgbmbd}, α::Float64)

  n   = 0.0
  ssλ = 0.0
  ssμ = 0.0
  for ξi in xi
    ssλ, ssμ, n = _sss_gbm(ξi, α, ssλ, ssμ, n)
  end

  return ssλ, ssμ, n
end





"""
    Σλ_gbm(xi::Vector{T}) where {T<: iTgbm}

Return the internal nodes of `Ξ`.
"""
function Σλ_gbm(xi::Vector{T}) where {T <: iTgbm}
  Σλ = 0.0
  for ξ in xi
    Σλ += Σλ_gbm(ξ)
  end
  return Σλ
end

