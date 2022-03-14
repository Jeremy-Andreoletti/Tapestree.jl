#=

Summary functions for vector of `iTree`

Ignacio Quintero Mächler

t(-_-t)

Created 03 09 2020
=#




"""
    time_quantile(r::Array{Array{Float64,1},1}, p::Array{Float64,1})

Return quantiles given by probabilities `p` vector.
"""
function time_quantile(r::Array{Array{Float64,1},1}, p::Array{Float64,1})

  fx = Array{Float64,2}(undef, lastindex(r), lastindex(p))
  for (i, ri) in enumerate(r)
    fx[i,:] = quantile(ri, p)
  end
  return fx
end




"""
    time_fun(f::Function, r::Array{Array{Float64,1},1})

Apply function `f` to each vector in `r` and return the value.
"""
function time_fun(f::Function, r::Array{Array{Float64,1},1})
  lr = lastindex(r)
  fx = Array{Float64,1}(undef, lr)
  for i in Base.OneTo(lr)
    fx[i] = f(r[i])
  end
  return fx
end




"""
    time_rate(tree::T, tdt::Float64, lv::Function) where {T <: iT}

Extract values from `lv` function at times sampled every `tdt` across the tree.
"""
function time_rate(tree::T, tdt::Float64, lv::Function) where {T <: iT}

  th = treeheight(tree)

  # make time vector (present = 0.0)
  ts  = [0.0:tdt:th...]
  reverse!(ts)

  # make vector of vector to push rates
  r = [Float64[] for i in Base.OneTo(lastindex(ts))]

  # do recursive
  _time_rate!(tree, ts, tdt, r, 1, th, lv)
  pop!(r)
  pop!(ts)

  return ts, r
end




"""
    _time_rate!(tree::T,
               ts  ::Array{Float64,1},
               tdt ::Float64,
               r   ::Array{Array{Float64,1},1},
               tii ::Int64,
               ct  ::Float64,
               lv  ::Function) where {T <: iT}

Extract values from `lv` function at times `ts` across the tree.
"""
@inline function _time_rate!(tree::T,
                             ts  ::Array{Float64,1},
                             tdt ::Float64,
                             r   ::Array{Array{Float64,1},1},
                             tii ::Int64,
                             ct  ::Float64,
                             lv  ::Function) where {T <: iT}

  et = e(tree)
  δt = dt(tree)
  vt = lv(tree)

  nts = Int64(fld(et - (ct - ts[tii]), tdt))
  tsr = tii:(tii + nts)

  # have to match ts times to lv vector
  @simd for i in tsr
    tsi = ts[i]
    bt  = ct - tsi
    ix  = fld(bt, δt)
    tts = δt *  ix
    ttf = δt * (ix + 1.0)
    Ix  = Int64(ix) + 1
    push!(r[i], linpred(bt, tts, ttf, vt[Ix], vt[Ix+1]))
  end

  if def1(tree)
    _time_rate!(tree.d1, ts, tdt, r, tii + nts + 1, ct - et, lv)
    _time_rate!(tree.d2, ts, tdt, r, tii + nts + 1, ct - et, lv)
  end
end




"""
    mcmc_array(treev::Array{T,1},
               δt   ::Float64,
               lv   ::Function) where {T <: iT}

Return an Array with a row for each sampled tree for interpolated
parameters accessed by `lv` at times determined by `δt`.
"""
function mcmc_array(treev::Array{T,1},
                    δt   ::Float64,
                    lv   ::Function) where {T <: iT}

  @inbounds begin

    vi = Float64[]
    extract_vector!(treev[1], vi, δt, 0.0, lv)

    ra = Array{Float64,2}(undef, lastindex(treev), lastindex(vi))
    ra[1,:] = vi

    for i in 2:lastindex(treev)
      vi = Float64[]
      extract_vector!(treev[i], vi, δt, 0.0, lv)
      ra[i, :] = vi
    end
  end

  return ra
end




"""
    extract_vector!(tree::T,
                    v   ::Array{Float64,1},
                    nδt ::Float64,
                    ct  ::Float64,
                    lv  ::Function) where {T <: iT}

Log-linearly predict Geometric Brownian motion for `λ` at times given by `nδt`
and return a vector.
"""
function extract_vector!(tree::T,
                         v   ::Array{Float64,1},
                         nδt ::Float64,
                         ct  ::Float64,
                         lv  ::Function) where {T <: iT}

  et = e(tree)
  δt = dt(tree)
  vt = lv(tree)
  n  = floor(Int64, (et - ct)/nδt)
  i1 = isapprox(et - ct, Float64(n)*nδt, atol = 1e-11) ? 0 : 1

  pv = Float64[]
  iti = ct
  for i in Base.OneTo(n+i1)
    ix  = fld(iti,δt)
    tts = δt *  ix
    ttf = δt * (ix + 1.0)
    Ix  = Int64(ix)
    push!(pv, linpred(iti + 0.5*δt, tts, ttf, vt[Ix+1], vt[Ix+2]))
    iti = Float64(i)*nδt + ct
  end

  append!(v, pv)

  if def1(tree)
    extract_vector!(tree.d1::T, v, nδt, max(0.0, iti - et), lv)
    extract_vector!(tree.d2::T, v, nδt, max(0.0, iti - et), lv)
  end
end




"""
    extract_vector!(tree::sTfbd,
                    v   ::Array{Float64,1},
                    nδt ::Float64,
                    ct  ::Float64,
                    lv  ::Function) where {T <: iT}

Log-linearly predict Geometric Brownian motion for `λ` at times given by `nδt`
and return a vector.
"""
function extract_vector!(tree::sTfbd,
                         v   ::Array{Float64,1},
                         nδt ::Float64,
                         ct  ::Float64,
                         lv  ::Function) where {T <: iT}

  et = e(tree)
  δt = dt(tree)
  vt = lv(tree)
  n  = floor(Int64, (et - ct)/nδt)
  i1 = isapprox(et - ct, Float64(n)*nδt, atol = 1e-11) ? 0 : 1

  pv = Float64[]
  iti = ct
  for i in Base.OneTo(n+i1)
    ix  = fld(iti,δt)
    tts = δt *  ix
    ttf = δt * (ix + 1.0)
    Ix  = Int64(ix)
    push!(pv, linpred(iti + 0.5*δt, tts, ttf, vt[Ix+1], vt[Ix+2]))
    iti = Float64(i)*nδt + ct
  end

  append!(v, pv)

  if def1(tree)
    extract_vector!(tree.d1::sTfbd, v, nδt, max(0.0, iti - et), lv)
  end
  if def2(tree)
    extract_vector!(tree.d2::sTfbd, v, nδt, max(0.0, iti - et), lv)
  end
end




"""
    linearize_gbm(tree::T, lv::Function) where {T <: iT}

Extract the parameters given by `lv` into a linear Array.
"""
function linearize_gbm(tree::T, lv::Function) where {T <: iT}
  v = Float64[]
  _linearize_gbm!(tree, lv, v)
  return v
end




"""
    _linearize_gbm!(tree::T,
                    lv  ::Function,
                    v   ::Array{Float64,1}) where {T <: iT}

Extract the parameters given by `lv` into a linear Array, initialized with an
array `v`.
"""
function _linearize_gbm!(tree::T,
                         lv  ::Function,
                         v   ::Array{Float64,1}) where {T <: iT}

  append!(v, lv(tree))
  if def1(tree)
    _linearize_gbm!(tree.d1::T, lv, v)
    _linearize_gbm!(tree.d2::T, lv, v)
  end
end




"""
    _linearize_gbm!(tree::sTfbd,
                    lv  ::Function,
                    v   ::Array{Float64,1}) where {T <: iT}

Extract the parameters given by `lv` into a linear Array, initialized with an
array `v`.
"""
function _linearize_gbm!(tree::sTfbd,
                         lv  ::Function,
                         v   ::Array{Float64,1}) where {T <: iT}

  append!(v, lv(tree))
  if def1(tree) _linearize_gbm!(tree.d1::T, lv, v) end
  if def2(tree) _linearize_gbm!(tree.d2::T, lv, v) end
end




"""
    extract_tree(tree::iTpb, nδt::Float64)

Log-linearly predict Geometric Brownian motion for `lv` at times given by `nδt`,
and return a tree.
"""
function extract_tree(tree::iTpb, nδt::Float64)

  et = e(tree)
  δt = dt(tree)
  v  = lλ(tree)
  n  = floor(Int64, et/nδt)
  i1 = isapprox(et, Float64(n)*nδt, atol = 1e-11) ? 0 : 1

  pv = Float64[]
  for i in Base.OneTo(n+i1)
    iti = Float64(i-1)*nδt
    ix  = floor(Int64, iti/δt) + 1
    tts = δt*Float64(ix-1)
    ttf = δt*Float64(ix)
    push!(pv, linpred(iti, tts, ttf, v[ix], v[ix+1]))
  end

  push!(pv, v[end])

  if isapprox(et, Float64(n)*nδt, atol = 1e-11)
    nfdt = nδt
  else
    nfdt = mod(et,nδt)
  end

  if def1(tree)
    iTpb(extract_tree(tree.d1, nδt),
            extract_tree(tree.d2, nδt), et, nδt, nfdt, pv)
  else
    iTpb(et, nδt, nfdt, pv)
  end
end




"""
    extractp(tree::iTbd, nδt::Float64)

Log-linearly predict Geometric Brownian motion for `lλ` and `lμ`
at times given by `nδt`.
"""
function extract_tree(tree::iTbd, nδt::Float64)

  et = e(tree)
  δt = dt(tree)
  vλ = lλ(tree)
  vμ = lμ(tree)
  n  = floor(Int64, et/nδt)

  i1  = isapprox(et, Float64(n)*nδt, atol = 1e-11) ? 0 : 1
  pλv = Float64[]
  pμv = Float64[]
  for i in Base.OneTo(n+i1)
    iti = Float64(i-1)*nδt
    ix  = floor(Int64, iti/δt) + 1
    tts = δt*Float64(ix-1)
    ttf = δt*Float64(ix)
    push!(pλv, linpred(iti, tts, ttf, vλ[ix], vλ[ix+1]))
    push!(pμv, linpred(iti, tts, ttf, vμ[ix], vμ[ix+1]))
  end

  push!(pλv, vλ[end])
  push!(pμv, vμ[end])

  if isapprox(et, Float64(n)*nδt, atol = 1e-11)
    nfdt = nδt
  else
    nfdt = mod(et,nδt)
  end

  if def1(tree)
    iTbd(extract_tree(tree.d1, nδt),
            extract_tree(tree.d2, nδt), et, nδt, nfdt, false, false, pλv, pμv)
  else
    iTbd(et, nδt, nfdt, false, false, pλv, pμv)
  end
end




"""
    linpred(val::Float64, x1::Float64, x2::Float64, y1::Float64, y2::Float64)

Estimate `y` at `x = val` according to linear interpolation for a range.
"""
linpred(val::Float64, x1::Float64, x2::Float64, y1::Float64, y2::Float64) =
  (y1 + (val - x1)*(y2 - y1)/(x2 - x1))::Float64




"""
    idxrange(x::Array{Float64,1}, val::Float64)

Get indexes in sorted vector `x` corresponding to the range in which
`val` is in using a sort of uniroot algorithm.
"""
function idxrange(x::Array{Float64,1}, val::Float64)

  @inbounds begin

    a::Int64 = 1

    if x[a] > val
      return a, false
    end

    b::Int64 = lastindex(x)

    if x[b] < val
      return b, false
    end

    mid::Int64 = div(b,2)

    while b-a > 1
      val < x[mid] ? b = mid : a = mid
      mid = div(b + a, 2)
    end

    if x[a] == val
      return a, false
    elseif x[b] == val
      return b, false
    else
      return a, true
    end

  end
end




"""
    iquantile(treev::Array{iTce,1}, p::Float64)

Make an `iTce` with the quantile specified by `p` in data specified in
function `lv`.
"""
function iquantile(treev::Array{iTce,1}, p::Float64)

  nt = lastindex(treev)
  t1 = treev[1]

  # make vector of lambdas
  vs = Array{Float64,1}[]
  for t in treev
    push!(vs, lλ(t))
  end

  sv = Float64[]
  # make fill vector to estimate statistics
  v = Array{Float64,1}(undef, nt)
  for i in Base.OneTo(lastindex(vs[1]))
    for t in Base.OneTo(nt)
      v[t] = vs[t][i]
    end
    push!(sv, quantile(v, p))
  end

  if isdefined(t1, :d1)
    treev1 = iTce[]
    for t in Base.OneTo(nt)
        push!(treev1, treev[t].d1)
    end
    treev2 = iTce[]
    for t in Base.OneTo(nt)
        push!(treev2, treev[t].d2)
    end

    iTce(iquantile(treev1, p), iquantile(treev2, p),
      e(t1), dt(t1), fdt(t1), isextinct(t1), true, sv)
  else
    iTce(e(t1), dt(t1), fdt(t1), isextinct(t1), true, sv)
  end
end




"""
    iquantile(treev::Array{iTct,1}, p::Float64)

Make an `iTct` with the quantile specified by `p` in data specified in
function `lv`.
"""
function iquantile(treev::Vector{iTct}, p::Float64)

  nt = lastindex(treev)
  t1 = treev[1]

  # make vector of lambdas
  vs = Array{Float64,1}[]
  for t in treev
    push!(vs, lλ(t))
  end

  sv = Float64[]
  # make fill vector to estimate statistics
  v = Array{Float64,1}(undef, nt)
  for i in Base.OneTo(lastindex(vs[1]))
    for t in Base.OneTo(nt)
      v[t] = vs[t][i]
    end
    push!(sv, quantile(v, p))
  end

  if isdefined(t1,:d1)
    treev1 = iTct[]
    for t in Base.OneTo(nt)
        push!(treev1, treev[t].d1)
    end
    treev2 = iTct[]
    for t in Base.OneTo(nt)
        push!(treev2, treev[t].d2)
    end

    iTct(iquantile(treev1, p), iquantile(treev2, p),
      e(t1), dt(t1), fdt(t1), isextinct(t1), true, sv)
  else
    iTct(e(t1), dt(t1), fdt(t1), isextinct(t1), true, sv)
  end

end




"""
    iquantile(reev::Vector{iTpb}, p::Float64)

Make an `iTpb` with the quantile specified by `p`.
"""
function iquantile(treev::Vector{iTpb}, p::Float64)

  nts = lastindex(treev)
  t1  = treev[1]

  # make vector of lambdas
  vs = Array{Float64,1}[]
  for t in treev
    push!(vs, lλ(t))
  end

  sv = Float64[]
  # make fill vector to estimate statistics
  v = Array{Float64,1}(undef, nts)
  for i in Base.OneTo(lastindex(vs[1]))
    for t in Base.OneTo(nts)
      v[t] = vs[t][i]
    end
    push!(sv, quantile(v, p))
  end

  if isdefined(t1, :d1)
    treev1 = iTpb[]
    for t in Base.OneTo(nts)
        push!(treev1, treev[t].d1)
    end
    treev2 = iTpb[]
    for t in Base.OneTo(nts)
        push!(treev2, treev[t].d2)
    end
    iTpb(iquantile(treev1, p), iquantile(treev2, p),
      e(t1), true, dt(t1), fdt(t1), sv)
  else
    iTpb(e(t1), true, dt(t1), fdt(t1), sv)
  end
end




"""
    iquantile(treev::Vector{iTbd}, p::Float64)

Make an `iTbd` with the quantile specified by `p` in data specified in
function `lv`.
"""
function iquantile(treev::Vector{iTbd}, p::Float64)

  nt  = lastindex(treev)

  t1 = treev[1]

  # make vector of lambdas and mus
  vsλ = Array{Float64,1}[]
  vsμ = Array{Float64,1}[]
  for t in treev
    push!(vsλ, lλ(t))
    push!(vsμ, lμ(t))
  end

  svλ = Float64[]
  svμ = Float64[]
  # make fill vector to estimate statistics
  vλ = Array{Float64,1}(undef, nt)
  vμ = Array{Float64,1}(undef, nt)
  for i in Base.OneTo(lastindex(vsλ[1]))
    for t in Base.OneTo(nt)
      vλ[t] = vsλ[t][i]
      vμ[t] = vsμ[t][i]
    end
    push!(svλ, quantile(vλ, p))
    push!(svμ, quantile(vμ, p))
  end

  if isdefined(t1, :d1)
    treev1 = iTbd[]
    for t in Base.OneTo(nt)
        push!(treev1, treev[t].d1)
    end
    treev2 = iTbd[]
    for t in Base.OneTo(nt)
        push!(treev2, treev[t].d2)
    end

    iTbd(iquantile(treev1, p),
            iquantile(treev2, p),
            e(t1), dt(t1), fdt(t1), false, false, svλ, svμ)
  else
    iTbd(e(t1), dt(t1), fdt(t1), false, false, svλ, svμ)
  end
end





"""
    iquantile(treev::Vector{iTfbd}, p::Float64)

Make an `iTfbd` with the quantile specified by `p` in data specified in
function `lv`.
"""
function iquantile(treev::Vector{iTfbd}, p::Float64)

  nt  = lastindex(treev)

  t1 = treev[1]

  # make vector of lambdas and mus
  vsλ = Array{Float64,1}[]
  vsμ = Array{Float64,1}[]
  for t in treev
    push!(vsλ, lλ(t))
    push!(vsμ, lμ(t))
  end

  svλ = Float64[]
  svμ = Float64[]
  # make fill vector to estimate statistics
  vλ = Array{Float64,1}(undef, nt)
  vμ = Array{Float64,1}(undef, nt)
  for i in Base.OneTo(lastindex(vsλ[1]))
    for t in Base.OneTo(nt)
      vλ[t] = vsλ[t][i]
      vμ[t] = vsμ[t][i]
    end
    push!(svλ, quantile(vλ, p))
    push!(svμ, quantile(vμ, p))
  end

  if def1(t1)
    treev1 = iTfbd[]
    for t in Base.OneTo(nt)
        push!(treev1, treev[t].d1)
    end

    if def2(t1)
      treev2 = iTfbd[]
      for t in Base.OneTo(nt)
          push!(treev2, treev[t].d2)
      end

      iTfbd(iquantile(treev1, p),
            iquantile(treev2, p),
            e(t1), dt(t1), fdt(t1), false, false, false, svλ, svμ)
    else
      iTfbd(iquantile(treev1, p),
            e(t1), dt(t1), fdt(t1), false, true, false, svλ, svμ)
    end
  else
    iTfbd(e(t1), dt(t1), fdt(t1), false, isfossil(t1), false, svλ, svμ)
  end
end



