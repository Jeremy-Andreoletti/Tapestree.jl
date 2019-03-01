#=

Create ODE numerical integration function

Ignacio Quintero Mächler

t(-_-t)

September 19 2017

=#

"""
    make_solver(odef, p0::Array{Float64,1})

Make **ODE** solver for `odef`.
"""
function make_solver(odef, p0::Array{Float64,1}, u0::Array{Float64,1})

  prob = ODEProblem(odef, u0, (0.0,1.0), p0)

  function f(u ::Array{Float64,1}, 
             p ::Array{Float64,1},
             ti::Float64,
             tf::Float64)

    prob = ODEProblem(prob.f, u, (ti, tf), p)

    solve(prob,
          Tsit5(), 
          save_everystep = false, 
          calck          = false,
          force_dtmin    = true,
          maxiters       = 100_000_000).u[2]::Array{Float64,1}
  end

  return f
end