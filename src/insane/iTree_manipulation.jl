#=

insane tree manipulation

Ignacio Quintero Mächler

t(-_-t)

Created 25 06 2020
=#


"""
    rm_stem(tree::T)  where {T <: iTree}

Removes stem branch.
"""
rm_stem!(tree::T)  where {T <: iTree} = 
  _rm_stem(tree)





"""
    _rm_stem(tree::T) where {T <: sT}

Remove stem branch.
"""
_rm_stem(tree::T) where {T <: sT} = sete!(tree, 0.0)




"""
    _rm_stem(tree::T) where {T <: iTgbm}

Remove stem branch.
"""
function _rm_stem(tree::T) where {T <: iTgbm}

  sete!(  tree, 0.0)
  setfdt!(tree, 0.0)
  lλe = lλ(tree)[end]
  setlλ!( tree, [lλe,lλe])

  return tree
end




"""
    _rm_stem(tree::iTgbmbd)

Remove stem branch.
"""
function _rm_stem(tree::iTgbmbd)

  sete!(  tree, 0.0)
  setfdt!(tree, 0.0)
  lλe = lλ(tree)[end]
  lμe = lμ(tree)[end]
  setlλ!( tree, [lλe, lλe])
  setlμ!( tree, [lμe, lμe])

  return tree
end





"""
    cutbottom(tree::T, c::Float64) where {T <: iTree}

Cut the bottom part of the tree after `c`.
"""
cutbottom(tree::T, c::Float64) where {T <: iTree} = _cutbottom(tree, c, 0.0)




"""
    _cutbottom(tree::sTpb, 
               c   ::Float64,
               t   ::Float64)

Cut the bottom part of the tree after `c`, starting at time `t`.
"""
function _cutbottom(tree::sTpb, 
                    c   ::Float64,
                    t   ::Float64)

  et = e(tree)

  if (t + et) > c
    tree = sTpb(c - t)
  else
    if isdefined(tree, :d1)
      tree.d1 = _cutbottom(tree.d1, c, t + et)
      tree.d2 = _cutbottom(tree.d2, c, t + et)
    end
  end

  return tree
end




"""
    _cutbottom(tree::sTbd, 
               c   ::Float64,
               t   ::Float64)

Cut the bottom part of the tree after `c`, starting at time `t`.
"""
function _cutbottom(tree::sTbd, 
                    c   ::Float64,
                    t   ::Float64)

  et = e(tree)

  if (t + et) > c
    tree = sTbd(c - t, false, isfix(tree))
  else
    if isdefined(tree, :d1)
      tree.d1 = _cutbottom(tree.d1, c, t + et)
      tree.d2 = _cutbottom(tree.d2, c, t + et)
    end
  end

  return tree
end




"""
    _cutbottom(tree::sTfbd, 
               c   ::Float64,
               t   ::Float64)

Cut the bottom part of the tree after `c`, starting at time `t`.
"""
function _cutbottom(tree::sTfbd, 
                    c   ::Float64,
                    t   ::Float64)

  et = e(tree)

  if (t + et) > c
    tree = sTfbd(c - t, false, false, isfix(tree))
  else
    if isdefined(tree, :d1) tree.d1 = _cutbottom(tree.d1, c, t + et) end
    if isdefined(tree, :d2) tree.d2 = _cutbottom(tree.d2, c, t + et) end
  end

  return tree
end




"""
    _cutbottom(tree::iTgbmpb, 
               c   ::Float64,
               t   ::Float64)

Cut the bottom part of the tree after `c`, starting at time `t`.
"""
function _cutbottom(tree::iTgbmpb, 
                    c   ::Float64,
                    t   ::Float64)

  et = e(tree)

  if (t + et) > c

    lλv = lλ(tree)
    δt  = dt(tree)
    fδt = fdt(tree)

    # find final lλ
    if isapprox(c - t, et)
      Ix = lastindex(lλv) - 1
      ix = Float64(Ix) - 1.0
    else
      ix  = fld(c - t, δt)
      Ix  = Int64(ix) + 1
    end

    tii = ix*δt
    tff = tii + δt
    if tff > et
      tff = tii + fδt
    end
    eλ = linpred(c - t, tii, tff, lλv[Ix], lλv[Ix+1])

    lλv = lλv[1:Ix]

    push!(lλv, eλ)

    tree = iTgbmpb(c - t, δt, c - t - tii, lλv)

  else
    if isdefined(tree, :d1)
      tree.d1 = _cutbottom(tree.d1, c, t + et)
      tree.d2 = _cutbottom(tree.d2, c, t + et)
    end
  end

  return tree
end




"""
    _cutbottom(tree::T, 
               c   ::Float64,
               t   ::Float64) where {T <: iTgbm}

Cut the bottom part of the tree after `c`, starting at time `t`.
"""
function _cutbottom(tree::T, 
                    c   ::Float64,
                    t   ::Float64) where {T <: iTgbm}

  et = e(tree)

  if (t + et) > c

    lλv = lλ(tree)
    δt  = dt(tree)
    fδt = fdt(tree)

    # find final lλ
    if isapprox(c - t, et)
      Ix = lastindex(lλv) - 1
      ix = Float64(Ix) - 1.0
    else
      ix  = fld(c - t, δt)
      Ix  = Int64(ix) + 1
    end
    tii = ix*δt
    tff = tii + δt
    if tff > et
      tff = tii + fδt
    end
    eλ = linpred(c - t, tii, tff, lλv[Ix], lλv[Ix+1])

    lλv = lλv[1:Ix]

    push!(lλv, eλ)

    tree = T(c - t, δt, c - t - tii, false, isfix(tree), lλv)

  else
    if isdefined(tree, :d1)
      tree.d1 = _cutbottom(tree.d1, c, t + et)
      tree.d2 = _cutbottom(tree.d2, c, t + et)
    end
  end

  return tree
end




"""
    _cutbottom(tree::iTgbmbd,
               c   ::Float64,
               t   ::Float64)

Cut the bottom part of the tree after `c`, starting at time `t`.
"""
function _cutbottom(tree::iTgbmbd,
                    c   ::Float64,
                    t   ::Float64)

  et = e(tree)

  if (t + et) > c

    lλv = lλ(tree)
    lμv = lμ(tree)
    δt  = dt(tree)
    fδt = fdt(tree)

    # find final lλ & lμ
    if isapprox(c - t, et)
      Ix = lastindex(lλv) - 1
      ix = Float64(Ix) - 1.0
    else
      ix  = fld(c - t, δt)
      Ix  = Int64(ix) + 1
    end
    tii = ix*δt
    tff = tii + δt
    if tff > et
      tff = tii + fδt
    end
    eλ = linpred(c - t, tii, tff, lλv[Ix], lλv[Ix+1])
    eμ = linpred(c - t, tii, tff, lμv[Ix], lμv[Ix+1])

    lλv = lλv[1:Ix]
    lμv = lμv[1:Ix]

    push!(lλv, eλ)
    push!(lμv, eμ)

    tree = iTgbmbd(c - t, δt, c - t - tii, false, isfix(tree), lλv, lμv)

  else
    if isdefined(tree, :d1)
      tree.d1 = _cutbottom(tree.d1, c, t + et)
      tree.d2 = _cutbottom(tree.d2, c, t + et)
    end
  end

  return tree
end




"""
    swapbranch!(treep::T,
                treec::T,
                nbtr ::T,
                dri  ::BitArray{1}, 
                ldr  ::Int64,
                it   ::Bool,
                ix   ::Int64) where {T <: iTree}

Swap branch given by `dri` by `nbtr` and return the tree.
"""
function swapbranch!(treep::T,
                     treec::T,
                     nbtr ::T,
                     dri  ::BitArray{1}, 
                     ldr  ::Int64,
                     it   ::Bool,
                     ix   ::Int64) where {T <: iTree}

  if ix === ldr
    nbtrp = deepcopy(nbtr)
    if !it
      nbtrp = addtree(nbtrp, treep) 
      nbtr  = addtree(nbtr,  treec) 
    end
    return nbtrp, nbtr
  elseif ix < ldr
    ifx1 = isfix(treec.d1::T)
    if ifx1 && isfix(treec.d2::T)
      ix += 1
      if dri[ix]
        treep.d1, treec.d1 = swapbranch!(treep.d1::T, treec.d1::T, nbtr::T, 
                                         dri, ldr, it, ix)
      else
        treep.d2, treec.d2 = swapbranch!(treep.d2::T, treec.d2::T, nbtr::T, 
                                         dri, ldr, it, ix)
      end
    elseif ifx1
      treep.d1, treec.d1 = swapbranch!(treep.d1::T, treec.d1::T, nbtr::T, 
                                       dri, ldr, it, ix)
    else
      treep.d2, treec.d2 = swapbranch!(treep.d2::T, treec.d2::T, nbtr::T, 
                                       dri, ldr, it, ix)
    end
  end

  return treep, treec
end




"""
    swapbranch!(treep::sTfbd,
                treec::sTfbd,
                nbtr ::sTfbd,
                dri  ::BitArray{1}, 
                ldr  ::Int64,
                it   ::Bool,
                iψ  ::Bool,
                ix   ::Int64)

Swap branch given by `dri` by `nbtr` and return the tree.
"""
function swapbranch!(treep::sTfbd,
                     treec::sTfbd,
                     nbtr ::sTfbd,
                     dri  ::BitArray{1}, 
                     ldr  ::Int64,
                     it   ::Bool,
                     iψ  ::Bool,
                     ix   ::Int64)

  if ix === ldr
    nbtrp = deepcopy(nbtr)
    if iψ 
      maketipsfossil!(nbtrp)
      maketipsfossil!(nbtr)
    end
    if !it || iψ
      nbtrp = addtree(nbtrp, treep) 
      nbtr  = addtree(nbtr,  treec) 
    end
    return nbtrp, nbtr
  
  elseif ix < ldr
    
    # Sampled ancestors
    defd1 = isdefined(treec::sTfbd, :d1)
    defd2 = isdefined(treec::sTfbd, :d2)
    if defd1 && !defd2
      ix += 1
      treep.d1, treec.d1 = swapbranch!(treep.d1::sTfbd, treec.d1::sTfbd, 
                                       nbtr::sTfbd, dri, ldr, it, ix)
      return treep, treec
    end
    if defd2 && !defd1
      ix += 1
      treep.d2, treec.d2 = swapbranch!(treep.d2::sTfbd, treec.d2::sTfbd, 
                                       nbtr::sTfbd, dri, ldr, it, ix)
      return treep, treec
    end

    # Birth
    ifx1 = isfix(treec.d1::sTfbd)
    if ifx1 && isfix(treec.d2::sTfbd)
      ix += 1
      if dri[ix]
        treep.d1, treec.d1 = swapbranch!(treep.d1::sTfbd, treec.d1::sTfbd, 
                                         nbtr::sTfbd, dri, ldr, it, ix)
      else
        treep.d2, treec.d2 = swapbranch!(treep.d2::sTfbd, treec.d2::sTfbd, 
                                         nbtr::sTfbd, dri, ldr, it, ix)
      end
    elseif ifx1
      treep.d1, treec.d1 = swapbranch!(treep.d1::sTfbd, treec.d1::sTfbd, 
                                       nbtr::sTfbd, dri, ldr, it, ix)
    else
      treep.d2, treec.d2 = swapbranch!(treep.d2::sTfbd, treec.d2::sTfbd, 
                                       nbtr::sTfbd, dri, ldr, it, ix)
    end
  end

  return treep, treec
end




"""
    swapbranch!(tree::T,
                nbtr::T,
                dri ::BitArray{1}, 
                ldr ::Int64,
                it  ::Bool,
                ix  ::Int64) where {T <: iTree}

Swap branch given by `dri` by `nbtr` and return the tree.
"""
function swapbranch!(tree::T,
                     nbtr::T,
                     dri ::BitArray{1}, 
                     ldr ::Int64,
                     it  ::Bool,
                     ix  ::Int64) where {T <: iTree}

  if ix === ldr
    if !it
      nbtr = addtree(nbtr, tree) 
    end
    return nbtr
  elseif ix < ldr
    ifx1 = isfix(tree.d1::T)
    if ifx1 && isfix(tree.d2::T)
      ix += 1
      if dri[ix]
        tree.d1 = swapbranch!(tree.d1::T, nbtr::T, dri, ldr, it, ix)
      else
        tree.d2 = swapbranch!(tree.d2::T, nbtr::T, dri, ldr, it, ix)
      end
    elseif ifx1
      tree.d1 = swapbranch!(tree.d1::T, nbtr::T, dri, ldr, it, ix)
    else
      tree.d2 = swapbranch!(tree.d2::T, nbtr::T, dri, ldr, it, ix)
    end
  end

  return tree
end




"""
    swapbranch!(tree::sTfbd,
                nbtr::sTfbd,
                dri ::BitArray{1}, 
                ldr ::Int64,
                it  ::Bool,
                iψ  ::Bool,
                ix  ::Int64)

Swap branch given by `dri` by `nbtr` and return the tree.
"""
function swapbranch!(tree::sTfbd,
                     nbtr::sTfbd,
                     dri ::BitArray{1}, 
                     ldr ::Int64,
                     it  ::Bool,
                     iψ  ::Bool,
                     ix  ::Int64)

  # branch reached
  if ix === ldr
    if iψ maketipsfossil!(nbtr) end
    if !it || iψ
      nbtr = addtree(nbtr, tree)
    end
    return nbtr
  
  elseif ix < ldr
    
    # sampled ancestors
    defd1 = isdefined(tree, :d1)
    defd2 = isdefined(tree, :d2)
    if defd1 && !defd2
      ix += 1
      tree.d1 = swapbranch!(tree.d1::sTfbd, nbtr::sTfbd, dri, ldr, it, iψ, ix)
      return tree
    end
    if defd2 && !defd1
      ix += 1
      tree.d2 = swapbranch!(tree.d2::sTfbd, nbtr::sTfbd, dri, ldr, it, iψ, ix)
      return tree
    end

    # birth
    ifx1 = isfix(tree.d1::sTfbd)
    if ifx1 && isfix(tree.d2::sTfbd)
      ix += 1
      if dri[ix]
        tree.d1 = swapbranch!(tree.d1::sTfbd, nbtr::sTfbd, dri, ldr, it, iψ, ix)
      else
        tree.d2 = swapbranch!(tree.d2::sTfbd, nbtr::sTfbd, dri, ldr, it, iψ, ix)
      end
    elseif ifx1
      tree.d1 = swapbranch!(tree.d1::sTfbd, nbtr::sTfbd, dri, ldr, it, iψ, ix)
    else
      tree.d2 = swapbranch!(tree.d2::sTfbd, nbtr::sTfbd, dri, ldr, it, iψ, ix)
    end
  end

  return tree
end




"""
    swapfossil!(tree::sTfbd,
                nbtr::sTfbd,
                dri ::BitArray{1}, 
                ldr ::Int64,
                ix  ::Int64)

Swap the subtree following the tip of the branch at `dri` by `nbtr`.
"""
function swapfossil!(tree::sTfbd,
                     nttr::sTfbd,
                     dri ::BitArray{1}, 
                     ldr ::Int64,
                     ix  ::Int64)
  # branch reached
  if ix === ldr
    # end of branch reached
    if isfossil(tree)
      tree.d1 = nttr
    elseif !istip(tree)
      if isfix(tree.d1::sTfbd)
        swapfossil!(tree.d1::sTfbd, nttr::sTfbd, dri, ldr, ix)
      else
        swapfossil!(tree.d2::sTfbd, nttr::sTfbd, dri, ldr, ix)
      end
    end

  elseif ix < ldr

    # sampled ancestors
    defd1 = isdefined(tree, :d1)
    defd2 = isdefined(tree, :d2)
    if defd1 && !defd2
      ix += 1
      swapfossil!(tree.d1::sTfbd, nttr::sTfbd, dri, ldr, ix)
      return nothing
    end
    if defd2 && !defd1
      ix += 1
      swapfossil!(tree.d2::sTfbd, nttr::sTfbd, dri, ldr, ix)
      return nothing
    end

    # birth
    ifx1 = isfix(tree.d1::sTfbd)
    if ifx1 && isfix(tree.d2::sTfbd)
      ix += 1
      if dri[ix]
        swapfossil!(tree.d1::sTfbd, nttr::sTfbd, dri, ldr, ix)
      else
        swapfossil!(tree.d2::sTfbd, nttr::sTfbd, dri, ldr, ix)
      end
    elseif ifx1
      swapfossil!(tree.d1::sTfbd, nttr::sTfbd, dri, ldr, ix)
    else
      swapfossil!(tree.d2::sTfbd, nttr::sTfbd, dri, ldr, ix)
    end
  end
end




"""
    addtree(tree::sTbd, dtree::sTbd) 

Add `dtree` to not-extinct tip in `tree` as speciation event, making
sure that the daughters of `dtree` are fixed.
"""
function addtree(tree::T, dtree::T) where {T <: iTree}

  if istip(tree::T) && isalive(tree::T)

    dtree = fixdstree(dtree)

    tree.d1 = dtree.d1
    tree.d2 = dtree.d2

    return tree
  end

  if isdefined(tree, :d1)
    tree.d1 = addtree(tree.d1::T, dtree::T)
    tree.d2 = addtree(tree.d2::T, dtree::T)
  end

  return tree
end




"""
    addtree(tree::sTfbd, dtree::sTfbd) 

Add `dtree` to not-extinct tip in `tree` as speciation event, making
sure that every daughter of `dtree` is fixed.
"""
function addtree(tree::sTfbd, dtree::sTfbd)

  if istip(tree::sTfbd) && isalive(tree::sTfbd)

    dtree = fixdstree(dtree::sTfbd)

    if isdefined(dtree, :d1) tree.d1 = dtree.d1 end
    if isdefined(dtree, :d2) tree.d2 = dtree.d2 end
    tree.iψ = isfossil(dtree)

    return tree
  end

  if isdefined(tree, :d1) tree.d1 = addtree(tree.d1::sTfbd, dtree::sTfbd) end
  if isdefined(tree, :d2) tree.d2 = addtree(tree.d2::sTfbd, dtree::sTfbd) end

  return tree
end




"""
    maketipsfossil!(tree::sTfbd) 

Change all alive tips to fossil tips.
"""
function maketipsfossil!(tree::sTfbd)

  if istip(tree::sTfbd) && isalive(tree::sTfbd)
    tree.iψ = true
  end

  if isdefined(tree, :d1) maketipsfossil!(tree.d1::sTfbd) end
  if isdefined(tree, :d2) maketipsfossil!(tree.d2::sTfbd) end
end




"""
    makepasttipsfossil!(tree::sTfbd) 

Change all past tips to fossil tips.
"""
makepasttipsfossil!(tree::sTfbd) = _makepasttipsfossil!(tree, treeheight(tree))




"""
    _makepasttipsfossil!(tree::sTfbd, th::Float64) 

Change all past tips to fossil tips, initialized at tree height `th`.
"""
function _makepasttipsfossil!(tree::sTfbd, th::Float64)

  th -= e(tree)

  if istip(tree::sTfbd) && !isapprox(th, 0, atol=1e-8)
    tree.iψ = true
  end

  if isdefined(tree, :d1) _makepasttipsfossil!(tree.d1::sTfbd, th) end
  if isdefined(tree, :d2) _makepasttipsfossil!(tree.d2::sTfbd, th) end
end




"""
    makepasttipsextinct!(tree::sTfbd) 

Change all past tips to extinct tips.
"""
makepasttipsextinct!(tree::sTfbd) = _makepasttipsextinct!(tree, treeheight(tree))




"""
    _makepasttipsextinct!(tree::sTfbd, th::Float64) 

Change all past tips to extinct tips, initialized at tree height `th`.
"""
function _makepasttipsextinct!(tree::sTfbd, th::Float64)

  th -= e(tree)

  if istip(tree::sTfbd) && !isapprox(th, 0, atol=1e-8)
    tree.iμ = true
  end

  if isdefined(tree, :d1) _makepasttipsextinct!(tree.d1::sTfbd, th) end
  if isdefined(tree, :d2) _makepasttipsextinct!(tree.d2::sTfbd, th) end
end




"""
    gbm_copy_dsf!(treec::T,
                  treep::T,
                  dri ::BitArray{1}, 
                  ldr ::Int64,
                  ix  ::Int64) where {T <: iTgbm}

Copy from `treep` to `treec` the contents of the fixed daughter branch.
"""
function gbm_copy_dsf!(treec::T,
                       treep::T,
                       dri ::BitArray{1}, 
                       ldr ::Int64,
                       ix  ::Int64) where {T <: iTgbm}

  if ix === ldr

    treecd1, treecd2 = fixds(treec)
    treepd1, treepd2 = fixds(treep)

    gbm_copy_f!(treecd1, treepd1)
    gbm_copy_f!(treecd2, treepd2)

  elseif ix < ldr
    ifx1 = isfix(treec.d1::T)
    if ifx1 && isfix(treec.d2::T)
      ix += 1
      if dri[ix]
        gbm_copy_dsf!(treec.d1::T, treep.d1::T, dri, ldr, ix)
      else
        gbm_copy_dsf!(treec.d2::T, treep.d2::T, dri, ldr, ix)
      end
    elseif ifx1
      gbm_copy_dsf!(treec.d1::T, treep.d1::T, dri, ldr, ix)
    else
      gbm_copy_dsf!(treec.d2::T, treep.d2::T, dri, ldr, ix)
    end
  end

  return nothing
end




"""
    gbm_copy_f!(tree::T,
                bbλ ::Array{Float64,1},
                ii  ::Int64) where {T <: iTgbm}

Copies the gbm birth-death in place for a fixed branch into the 
help arrays `bbλ`.
"""
function gbm_copy_f!(tree::T,
                     bbλ ::Array{Float64,1},
                     ii  ::Int64) where {T <: iTgbm}

  if !iszero(fdt(tree))
    lλv = lλ(tree)
    lt  = lastindex(lλv)

    @simd for i in Base.OneTo(lt)
      ii     += 1
      bbλ[ii] = lλv[i]
    end
  end

  if !istip(tree)
    if isfix(tree.d1::T)
      gbm_copy_f!(tree.d1::T, bbλ, ii-1)
    else
      gbm_copy_f!(tree.d2::T, bbλ, ii-1)
    end
  end

  return nothing
end





"""
    gbm_copy_f!(tree::iTgbmbd,
                bbλ ::Array{Float64,1},
                bbμ ::Array{Float64,1},
                ii  ::Int64)

Copies the gbm birth-death in place for a fixed branch into the 
help arrays `bbλ` and `bbμ`.
"""
function gbm_copy_f!(tree::iTgbmbd,
                     bbλ ::Array{Float64,1},
                     bbμ ::Array{Float64,1},
                     ii  ::Int64)

  if !iszero(fdt(tree))
    lλv = lλ(tree)
    lμv = lμ(tree)
    lt  = lastindex(lλv)

    @simd for i in Base.OneTo(lt)
      ii     += 1
      bbλ[ii] = lλv[i]
      bbμ[ii] = lμv[i]
    end
  end

  if !istip(tree)
    if isfix(tree.d1::iTgbmbd)
      gbm_copy_f!(tree.d1::iTgbmbd, bbλ, bbμ, ii-1)
    else
      gbm_copy_f!(tree.d2::iTgbmbd, bbλ, bbμ, ii-1)
    end
  end

  return nothing
end




"""
    gbm_copy_f!(treec::T,
                treep::T) where {T <: iTgbm}

Copies the gbm birth-death in place for a fixed branch.
"""
function gbm_copy_f!(treec::T,
                     treep::T) where {T <: iTgbm}

  lλp = lλ(treep)
  l   = lastindex(lλp)
  unsafe_copyto!(lλ(treec), 1, lλp, 1, l)

  if !istip(treec)
    ifx1 = isfix(treec.d1::T)
    if ifx1 && isfix(treec.d2::T)
      return nothing
    elseif ifx1
      gbm_copy_f!(treec.d1::T, treep.d1::T)
      gbm_copy!(  treec.d2::T, treep.d2::T)
    else
      gbm_copy!(  treec.d1::T, treep.d1::T)
      gbm_copy_f!(treec.d2::T, treep.d2::T)
    end
  end

  return nothing
end




"""
    gbm_copy!(treec::T,
              treep::T) where {T <: iTgbm}

Copies the gbm birth-death in place.
"""
function gbm_copy!(treec::T,
                   treep::T) where {T <: iTgbm}

  lλp = lλ(treep)
  l   = lastindex(lλp)
  unsafe_copyto!(lλ(treec), 1, lλp, 1, l)

  if isdefined(treec, :d1)
    gbm_copy!(treec.d1::T, treep.d1::T)
    gbm_copy!(treec.d2::T, treep.d2::T)
  end

  return nothing
end




"""
    gbm_copy!(treec::sTfbd, treep::sTfbd)

Copies the gbm birth-death in place.
"""
function gbm_copy!(treec::sTfbd, treep::sTfbd)

  lλp = lλ(treep)
  l   = lastindex(lλp)
  unsafe_copyto!(lλ(treec), 1, lλp, 1, l)

  if isdefined(treec, :d1) gbm_copy!(treec.d1::sTfbd, treep.d1::sTfbd) end
  if isdefined(treec, :d2) gbm_copy!(treec.d2::sTfbd, treep.d2::sTfbd) end

  return nothing
end




"""
    gbm_copy_f!(treec::iTgbmbd,
                treep::iTgbmbd)

Copies the gbm birth-death in place for a fixed branch.
"""
function gbm_copy_f!(treec::iTgbmbd,
                     treep::iTgbmbd)

  lλp = lλ(treep)
  l   = lastindex(lλp)
  unsafe_copyto!(lλ(treec), 1, lλp, 1, l)
  unsafe_copyto!(lμ(treec), 1, lμ(treep), 1, l)

  if !istip(treec)
    ifx1 = isfix(treec.d1::iTgbmbd)
    if ifx1 && isfix(treec.d2::iTgbmbd)
      return nothing
    elseif ifx1
      gbm_copy_f!(treec.d1::iTgbmbd, treep.d1::iTgbmbd)
      gbm_copy!(  treec.d2::iTgbmbd, treep.d2::iTgbmbd)
    else
      gbm_copy!(  treec.d1::iTgbmbd, treep.d1::iTgbmbd)
      gbm_copy_f!(treec.d2::iTgbmbd, treep.d2::iTgbmbd)
    end
  end

  return nothing
end




"""
    gbm_copy!(treec::iTgbmbd,
              treep::iTgbmbd)

Copies the gbm birth-death in place.
"""
function gbm_copy!(treec::iTgbmbd,
                   treep::iTgbmbd)

  lλp = lλ(treep)
  l   = lastindex(lλp)
  unsafe_copyto!(lλ(treec), 1, lλp, 1, l)
  unsafe_copyto!(lμ(treec), 1, lμ(treep), 1, l)

  if isdefined(treec, :d1)
    gbm_copy!(treec.d1::iTgbmbd, treep.d1::iTgbmbd)
    gbm_copy!(treec.d2::iTgbmbd, treep.d2::iTgbmbd)
  end

  return nothing
end




"""
    fixalive!(tree::T) where T <: iTree
Fixes the the path from root to the only species alive.
"""
function fixalive!(tree::T) where T <: iTree

  if istip(tree::T) 
    if isalive(tree::T)
      fix!(tree::T)
      return true
    end
  else
    f = fixalive!(tree.d2::T)
    if f 
      fix!(tree)
      return true
    end
    f = fixalive!(tree.d1::T)
    if f 
      fix!(tree)
      return true
    end
  end

  return false
end




"""
    fixalive!(tree::sTfbd) where T <: iTree

Fixes the path from root to the only species alive.
"""
function fixalive!(tree::sTfbd) where T <: iTree

  if istip(tree::sTfbd) && isalive(tree::sTfbd)
    fix!(tree::sTfbd)
    return true
  end

  if isdefined(tree, :d2)
    f = fixalive!(tree.d2::sTfbd)
    if f 
      fix!(tree)
      return true
    end
  end

  if isdefined(tree, :d1)
    f = fixalive!(tree.d1::sTfbd)
    if f 
      fix!(tree)
      return true
    end
  end

  return false
end




"""
    fixrtip!(tree::T) where T <: iTree

Fixes the the path for a random non extinct tip.
"""
fixrtip!(tree::T) where T <: iTree = _fixrtip!(tree, ntipsalive(tree))



"""
    _fixrtip!(tree::T, na::Int64) where {T <: iTgbm}

Fixes the the path for a random non extinct tip among `na`.
"""
function _fixrtip!(tree::T, na::Int64) where T <: iTree

  fix!(tree)

  if isdefined(tree, :d1)
    if isextinct(tree.d1)
      _fixrtip!(tree.d2, na)
    elseif isextinct(tree.d2)
      _fixrtip!(tree.d1, na)
    else
      na1 = ntipsalive(tree.d1)
      # probability proportional to number of lineages
      if (fIrand(na) + 1) > na1
        _fixrtip!(tree.d2, na - na1)
      else
        _fixrtip!(tree.d1, na1)
      end
    end
  end
end




"""
    _fixrtip!(tree::sTfbd, na::Int64)

Fixes the the path for a random non extinct tip among `na`.
"""
function _fixrtip!(tree::sTfbd, na::Int64)

  fix!(tree)

  if isdefined(tree, :d1)
    if isdefined(tree, :d2)
      if isextinct(tree.d1::sTfbd)
        _fixrtip!(tree.d2::sTfbd, na)
      elseif isextinct(tree.d2::sTfbd)
        _fixrtip!(tree.d1::sTfbd, na)
      else
        na1 = ntipsalive(tree.d1::sTfbd)
        # probability proportional to number of lineages
        if (fIrand(na) + 1) > na1
          _fixrtip!(tree.d2::sTfbd, na - na1)
        else
          _fixrtip!(tree.d1::sTfbd, na1)
        end
      end
    else
      _fixrtip!(tree.d1::sTfbd, na)
    end
  
  elseif isdefined(tree, :d2) && isalive(tree.d2::sTfbd)
    _fixrtip!(tree.d2::sTfbd, na)
  end
end




"""
    graftree!(tree ::T,
              stree::T,
              dri  ::BitArray{1},
              h    ::Float64,
              ldr  ::Int64,
              thc  ::Float64,
              ix   ::Int64) where {T <: iTree}

Graft `stree` into `tree` given the address `idr`.
"""
function graftree!(tree ::T,
                   stree::T,
                   dri  ::BitArray{1},
                   h    ::Float64,
                   ldr  ::Int64,
                   thc  ::Float64,
                   ix   ::Int64) where {T <: iTree}

  if ix === ldr 
    if thc > h > (thc - e(tree))
      ne = thc - h
      adde!(tree, -ne)
      tree = rand() <= 0.5 ? T(tree, stree, ne, false, true) :
                             T(stree, tree, ne, false, true)
    else
      if isfix(tree.d1)
        tree.d1 = 
          graftree!(tree.d1::T, stree, dri, h, ldr, thc - e(tree), ix)
      else
        tree.d2 =
          graftree!(tree.d2::T, stree, dri, h, ldr, thc - e(tree), ix)
      end
    end
  elseif ix < ldr
    ifx1 = isfix(tree.d1)
    if ifx1 && isfix(tree.d2)
      ix += 1
      if dri[ix]
        tree.d1 = 
          graftree!(tree.d1::T, stree, dri, h, ldr, thc - e(tree), ix)
      else
        tree.d2 = 
          graftree!(tree.d2::T, stree, dri, h, ldr, thc - e(tree), ix)
      end
    elseif ifx1
      tree.d1 = 
        graftree!(tree.d1::T, stree, dri, h, ldr, thc - e(tree), ix)
    else
      tree.d2 =
        graftree!(tree.d2::T, stree, dri, h, ldr, thc - e(tree), ix)
    end
  end

  return tree
end




"""
    graftree!(tree ::sTfbd,
              stree::sTfbd,
              dri  ::BitArray{1},
              h    ::Float64,
              ldr  ::Int64,
              thc  ::Float64,
              ix   ::Int64)

Graft `stree` into `tree` given the address `idr`.
"""
function graftree!(tree ::sTfbd,
                   stree::sTfbd,
                   dri  ::BitArray{1},
                   h    ::Float64,
                   ldr  ::Int64,
                   thc  ::Float64,
                   ix   ::Int64)

  if ix === ldr 
    if thc > h > (thc - e(tree))
      ne = thc - h
      adde!(tree, -ne)
      tree = rand() <= 0.5 ? sTfbd(tree, stree, ne, false, false, true) :
                             sTfbd(stree, tree, ne, false, false, true)
    else
      if isfix(tree.d1)
        tree.d1 = 
          graftree!(tree.d1::sTfbd, stree, dri, h, ldr, thc - e(tree), ix)
      else
        tree.d2 =
          graftree!(tree.d2::sTfbd, stree, dri, h, ldr, thc - e(tree), ix)
      end
    end
  elseif ix < ldr
    ifx1 = isdefined(stree, :d1) && isfix(tree.d1)
    if ifx1 && isdefined(stree, :d2) && isfix(tree.d2)
      ix += 1
      if dri[ix]
        tree.d1 = 
          graftree!(tree.d1::sTfbd, stree, dri, h, ldr, thc - e(tree), ix)
      else
        tree.d2 = 
          graftree!(tree.d2::sTfbd, stree, dri, h, ldr, thc - e(tree), ix)
      end
    elseif ifx1
      tree.d1 = 
        graftree!(tree.d1::sTfbd, stree, dri, h, ldr, thc - e(tree), ix)
    else
      tree.d2 =
        graftree!(tree.d2::sTfbd, stree, dri, h, ldr, thc - e(tree), ix)
    end
  end

  return tree
end




"""
    prunetree!(tree::T, 
               dri ::BitArray{1}, 
               ldr ::Int64,
               wpr ::Int64,
               ix  ::Int64, 
               px  ::Int64) where {T <: iTree}

Prune tree at branch given by `dri` and grafted `wpr`.
"""
function prunetree!(tree::T, 
                    dri ::BitArray{1}, 
                    ldr ::Int64,
                    wpr ::Int64,
                    ix  ::Int64, 
                    px  ::Int64) where {T <: iTree}

  if ix === ldr
    if px === wpr
      if isfix(tree.d1::T)
        ne  = e(tree) + e(tree.d1)
        sete!(tree.d1, ne)
        tree = tree.d1
      elseif isfix(tree.d2::T)
        ne  = e(tree) + e(tree.d2)
        sete!(tree.d2, ne)
        tree = tree.d2
      end
    else
      px += 1
      if isfix(tree.d1::T)
        tree.d1 = 
          prunetree!(tree.d1::T, dri, ldr, wpr, ix, px)
      else
        tree.d2 =
          prunetree!(tree.d2::T, dri, ldr, wpr, ix, px)
      end
    end
  elseif ix < ldr
    ifx1 = isfix(tree.d1::T)
    if ifx1 && isfix(tree.d2::T)
      ix += 1
      if dri[ix]
        tree.d1 = 
          prunetree!(tree.d1::T, dri, ldr, wpr, ix, px)
      else
        tree.d2 = 
          prunetree!(tree.d2::T, dri, ldr, wpr, ix, px)
      end
    elseif ifx1
      tree.d1 = 
        prunetree!(tree.d1::T, dri, ldr, wpr, ix, px)
    else
      tree.d2 =
        prunetree!(tree.d2::T, dri, ldr, wpr, ix, px)
    end
  end

  return tree
end




"""
    prunetree!(tree::sTfbd, 
               dri ::BitArray{1}, 
               ldr ::Int64,
               wpr ::Int64,
               ix  ::Int64, 
               px  ::Int64)

Prune tree at branch given by `dri` and grafted `wpr`.
"""
function prunetree!(tree::sTfbd, 
                    dri ::BitArray{1}, 
                    ldr ::Int64,
                    wpr ::Int64,
                    ix  ::Int64, 
                    px  ::Int64)

  if ix === ldr
    if px === wpr
      if isfix(tree.d1::sTfbd)
        ne  = e(tree) + e(tree.d1)
        sete!(tree.d1, ne)
        tree = tree.d1
      elseif isfix(tree.d2::sTfbd)
        ne  = e(tree) + e(tree.d2)
        sete!(tree.d2, ne)
        tree = tree.d2
      end
    else
      px += 1
      if isfix(tree.d1::sTfbd)
        tree.d1 = 
          prunetree!(tree.d1::sTfbd, dri, ldr, wpr, ix, px)
      else
        tree.d2 =
          prunetree!(tree.d2::sTfbd, dri, ldr, wpr, ix, px)
      end
    end
  elseif ix < ldr
    ifx1 = isdefined(stree, :d1) && isfix(tree.d1::sTfbd)
    if ifx1 && isdefined(stree, :d2) && isfix(tree.d2::sTfbd)
      ix += 1
      if dri[ix]
        tree.d1 = 
          prunetree!(tree.d1::sTfbd, dri, ldr, wpr, ix, px)
      else
        tree.d2 = 
          prunetree!(tree.d2::sTfbd, dri, ldr, wpr, ix, px)
      end
    elseif ifx1
      tree.d1 = 
        prunetree!(tree.d1::sTfbd, dri, ldr, wpr, ix, px)
    else
      tree.d2 =
        prunetree!(tree.d2::sTfbd, dri, ldr, wpr, ix, px)
    end
  end

  return tree
end




"""
    remove_extinct(tree::iTgbmce)

Remove extinct tips from `iTgbmce`.
"""
function remove_extinct(tree::iTgbmce)

  if isdefined(tree, :d1)

    tree.d1 = remove_extinct(tree.d1)
    tree.d2 = remove_extinct(tree.d2)

    if isextinct(tree.d1)
      if isextinct(tree.d2)
        return iTgbmce(e(tree), dt(tree), fdt(tree), 
          true, isfix(tree), lλ(tree))
      else
        ne  = e(tree) + e(tree.d2)
        lλ0 = lλ(tree)

        pop!(lλ0)
        prepend!(lλ(tree.d2), lλ0) 
        fdt0 = fdt(tree) + fdt(tree.d2)
        if fdt0 > dt(tree) 
          fdt0 -= dt(tree) 
        end
        setfdt!(tree, fdt0) 

        tree = tree.d2
        sete!(tree, ne)
      end
    elseif isextinct(tree.d2)
      ne  = e(tree) + e(tree.d1)
      lλ0 = lλ(tree)

      pop!(lλ0)
      prepend!(lλ(tree.d1), lλ0) 
      fdt0 = fdt(tree) + fdt(tree.d1)

      if fdt0 > dt(tree) 
        fdt0 -= dt(tree) 
      end
      setfdt!(tree, fdt0) 

      tree = tree.d1
      sete!(tree, ne)
    end
  end

  return tree
end




"""
    remove_extinct(tree::iTgbmct)

Remove extinct tips from `iTgbmct`.
"""
function remove_extinct(tree::iTgbmct)

  if isdefined(tree, :d1)

    tree.d1 = remove_extinct(tree.d1)
    tree.d2 = remove_extinct(tree.d2)

    if isextinct(tree.d1)
      if isextinct(tree.d2)
        return iTgbmct(e(tree), dt(tree), fdt(tree), 
          true, isfix(tree), lλ(tree))
      else
        ne = e(tree) + e(tree.d2)
        lλ0 = lλ(tree)

        pop!(lλ0)
        prepend!(lλ(tree.d2), lλ0) 

        fdt0 = fdt(tree) + fdt(tree.d2)
        if fdt0 > dt(tree) 
          fdt0 -= dt(tree) 
        end
        setfdt!(tree, fdt0) 

        tree = tree.d2
        sete!(tree, ne)

      end
    elseif isextinct(tree.d2)
      ne = e(tree) + e(tree.d1)
      lλ0 = lλ(tree)

      pop!(lλ0)
      prepend!(lλ(tree.d1), lλ0) 

      fdt0 = fdt(tree) + fdt(tree.d1)

      if fdt0 > dt(tree) 
        fdt0 -= dt(tree) 
      end

      setfdt!(tree, fdt0) 

      tree = tree.d1
      sete!(tree, ne)
    end
  end

  return tree
end




"""
    remove_extinct(tree::iTgbmbd)

Remove extinct tips from `iTgbmbd`.
"""
function remove_extinct(tree::iTgbmbd)

  if isdefined(tree, :d1)

    tree.d1 = remove_extinct(tree.d1)
    tree.d2 = remove_extinct(tree.d2)

    if isextinct(tree.d1)
      if isextinct(tree.d2)
        return iTgbmbd(e(tree), dt(tree), fdt(tree), 
          true, isfix(tree), lλ(tree), lμ(tree))
      else
        ne = e(tree) + e(tree.d2)
        lλ0 = lλ(tree)
        lμ0 = lμ(tree)

        pop!(lλ0)
        pop!(lμ0)

        prepend!(lλ(tree.d2), lλ0) 
        prepend!(lμ(tree.d2), lμ0)

        fdt0 = fdt(tree) + fdt(tree.d2)
        if fdt0 > dt(tree) 
          fdt0 -= dt(tree) 
        end
        setfdt!(tree, fdt0) 

        tree = tree.d2
        sete!(tree, ne)
      end
    elseif isextinct(tree.d2)

      ne = e(tree) + e(tree.d1)
      lλ0 = lλ(tree)
      lμ0 = lμ(tree)

      pop!(lλ0)
      pop!(lμ0)

      prepend!(lλ(tree.d1), lλ0) 
      prepend!(lμ(tree.d1), lμ0)

      fdt0 = fdt(tree) + fdt(tree.d1)
      if fdt0 > dt(tree) 
        fdt0 -= dt(tree) 
      end
      setfdt!(tree, fdt0) 

      tree = tree.d1
      sete!(tree, ne)
    end
  end

  return tree
end




"""
    remove_extinct(treev::Array{T,1}) where {T <: iTree}

Remove extinct taxa for a vector of trees.
"""
function remove_extinct(treev::Array{T,1}) where {T <: iTree}

  treevne = T[]
  for t in treev
    push!(treevne, remove_extinct(deepcopy(t)))
  end

  return treevne
end




"""
    remove_extinct(tree::sTbd)

Remove extinct tips from `sTbd`.
"""
function remove_extinct(tree::sTbd)

  if isdefined(tree, :d1)
    tree.d1 = remove_extinct(tree.d1)
    tree.d2 = remove_extinct(tree.d2)

    if isextinct(tree.d1)
      if isextinct(tree.d2)
        return sTbd(e(tree), true, isfix(tree))
      else
        ne  = e(tree) + e(tree.d2)
        tree = tree.d2
        sete!(tree, ne)
      end
    elseif isextinct(tree.d2)
      ne  = e(tree) + e(tree.d1)
      tree = tree.d1
      sete!(tree, ne)
    end
  end

  return tree
end




"""
    remove_extinct(tree::sTfbd)

Remove extinct tips from `sTfbd`.
"""
function remove_extinct(tree::sTfbd)
  defd1 = isdefined(tree, :d1)
  defd2 = isdefined(tree, :d2)

  if defd1 tree.d1 = remove_extinct(tree.d1) end
  if defd2 tree.d2 = remove_extinct(tree.d2) end

  if !defd1 && !defd2
    return tree
  end

  extd1 = defd1 && isextinct(tree.d1)
  extd2 = defd2 && isextinct(tree.d2)

  # 2 extinct branches or sampled ancestor -> extinct tip
  if extd1 && extd2 || (extd1 && !defd2) || (!defd1 && extd2)
    return sTfbd(e(tree), true, isfix(tree))
  end

  # 1 extinct and 1 alive branch -> keep only the alive one
  if extd1 ne = e(tree) + e(tree.d2) ; tree = tree.d2 ; sete!(tree, ne) end
  if extd2 ne = e(tree) + e(tree.d1) ; tree = tree.d1 ; sete!(tree, ne) end

  return tree
end




"""
    remove_fossils!(tree::sTfbd)

Remove fossils from `sTfbd`.
"""
function remove_fossils!(tree::sTfbd)
  defd1 = isdefined(tree, :d1)
  defd2 = isdefined(tree, :d2)

  while isfossil(tree)
    if isdefined(tree, :d1)
      tree.d1.e += tree.e
      tree = tree.d1
    elseif isdefined(tree, :d2)
      tree.d2.e += tree.e
      tree = tree.d2
    else
      break
    end
  end


  if isdefined(tree, :d1) tree.d1 = remove_fossils!(tree.d1) end
  if isdefined(tree, :d2) tree.d2 = remove_fossils!(tree.d2) end

  if isdefined(tree, :d1)
    if isfossil(tree.d1)
      if isfossil(tree.d2)
        return sTfbd(1.0, false, true, true)
      else
        tree.d2.e += tree.e
        tree = tree.d2
      end
    elseif isfossil(tree.d2)
      tree.d1.e += tree.e
      tree = tree.d1
    end
  end
  return tree
end




"""
    remove_sampled_ancestors!(tree::sTfbd)

Remove sampled ancestors (non-tip fossils) from `sTfbd`.
"""
function remove_sampled_ancestors!(tree::sTfbd)
  defd1 = isdefined(tree, :d1)
  defd2 = isdefined(tree, :d2)

  while isfossil(tree)
    if isdefined(tree, :d1)
      tree.d1.e += tree.e
      tree = tree.d1
    elseif isdefined(tree, :d2)
      tree.d2.e += tree.e
      tree = tree.d2
    else
      break
    end
  end


  if isdefined(tree, :d1) tree.d1 = remove_sampled_ancestors!(tree.d1) end
  if isdefined(tree, :d2) tree.d2 = remove_sampled_ancestors!(tree.d2) end

  return tree
end




"""
    reconstructed(tree::T) where {T <: iTree}

Returns the reconstructed tree, i.e. the observed tree from sampled extant 
tips and fossils.
"""
reconstructed(tree::T) where {T <: iTree} = remove_extinct(tree)
# For all trees without fossils, it simply means removing extinct lineages




"""
    reconstructed(tree::sTfbd)

Returns the reconstructed tree, i.e. the observed tree from sampled extant 
tips and fossils.
"""
function reconstructed(tree::sTfbd)
  defd1 = isdefined(tree, :d1)
  defd2 = isdefined(tree, :d2)

  if defd1 tree.d1 = reconstructed(tree.d1) end
  if defd2 tree.d2 = reconstructed(tree.d2) end

  if !defd1 && !defd2
    return tree
  end

  extd1 = defd1 && isextinct(tree.d1) && !isfossil(tree.d1)
  extd2 = defd2 && isextinct(tree.d2) && !isfossil(tree.d2)

  # 2 extinct branches -> extinct tip
  if extd1 && extd2
    return sTfbd(e(tree), true, isfix(tree))
  end

  # sampled ancestor -> fossil tip
  if (extd1 && !defd2) || (!defd1 && extd2)
    return sTfbd(e(tree), false, true, isfix(tree))
  end

  # 1 extinct and 1 alive branch -> keep only the alive one
  if extd1 ne = e(tree) + e(tree.d2) ; tree = tree.d2 ; sete!(tree, ne) end
  if extd2 ne = e(tree) + e(tree.d1) ; tree = tree.d1 ; sete!(tree, ne) end

  return tree
end




"""
    fixtree!(tree::T) where {T <: iTree}

Fix all `tree`.
"""
function fixtree!(tree::T) where {T <: iTree}
  fix!(tree)
  if isdefined(tree, :d1)
    fixtree!(tree.d1)
    fixtree!(tree.d2)
  end
end




"""
    fixtree!(tree::sTfbd)

Fix all `tree`.
"""
function fixtree!(tree::sTfbd)
  fix!(tree)
  if isdefined(tree, :d1) fixtree!(tree.d1) end
  if isdefined(tree, :d2) fixtree!(tree.d2) end
end




"""
    fix!(tree::T) where {T <: iTree}

Fix `tree`.
"""
fix!(tree::T) where {T <: iTree} = setproperty!(tree, :fx, true)




"""
    setlλ!(tree::T, lλ::Array{Float64,1}) where {T <: iTgbm}

Set number of `δt` for `tree`.
"""
setlλ!(tree::T, lλ::Array{Float64,1}) where {T <: iTgbm} = 
  setproperty!(tree, :lλ, lλ)




"""
    setlμ!(tree::T, lμ::Array{Float64,1}) where {T <: iTgbmbd}

Set number of `δt` for `tree`.
"""
setlμ!(tree::T, lμ::Array{Float64,1}) where {T <: iTgbmbd} = 
  setproperty!(tree, :lμ, lμ)




"""
  setfdt!(tree::T, fdt::Float64) where {T <: iTgbm}

Set number of `δt` for `tree`.
"""
setfdt!(tree::T, fdt::Float64) where {T <: iTgbm} = 
  setproperty!(tree, :fdt, fdt)




"""
  setdt!(tree::T, dt::Float64) where {T <: iTgbm}

Set number of `δt` for `tree`.
"""
setdt!(tree::T, dt::Float64) where {T <: iTgbm} = 
  setproperty!(tree, :dt, dt)




"""
  sete!(tree::T, e::Float64) where {T <: iTree}

Set endant edge for `tree`.
"""
sete!(tree::T, e::Float64) where {T <: iTree} = setproperty!(tree, :e, e)




"""
  adde!(tree::T, e::Float64) where {T <: iTree}

Add `e` to edge of `tree`.
"""
adde!(tree::T, e::Float64) where {T <: iTree} = tree.e += e




"""
  setd1!(tree::T,  stree::T) where {T <: iTree}

Set `d1` to `stree` in `tree`.
"""
setd1!(tree::T,  stree::T) where {T <: iTree} = setproperty!(tree, :d1, stree)




"""
  setd2!(tree::T,  stree::T) where {T <: iTree}

Set `d2` to `stree` in `tree`.
"""
setd2!(tree::T,  stree::T) where {T <: iTree} = setproperty!(tree, :d2, stree)



