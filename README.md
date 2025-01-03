# PlotlyKaleido.jl

**PlotlyKaleido.jl** is for saving [Plotly.js](https://plotly.com/javascript/) plots in a variety of formats using [Kaleido](https://github.com/plotly/Kaleido).

```julia
julia> PlotlyKaleido.ALL_FORMATS
7-element Vector{String}:
 "png"
 "jpeg"
 "webp"
 "svg"
 "pdf"
 "eps"
 "json"
```

This code was originally part of [PlotlyJS.jl](https://github.com/JuliaPlots/PlotlyJS.jl).




## Usage


```julia
using PlotlyKaleido
import PlotlyLight, EasyConfig, PlotlyJS

PlotlyKaleido.start()  # start Kaleido server

p1 = PlotlyLight.Plot(EasyConfig.Config(x = rand(10)))

p2 = PlotlyJS.plot(PlotlyJS.scatter(x = rand(10)))

# PlotlyKaleido is agnostic about which package you use to make Plotly plots!
PlotlyKaleido.savefig(p1, "plot1.png")
PlotlyKaleido.savefig(p2, "plot2.png")
```

If needed, you can restart the server:

```julia
PlotlyKaleido.restart()
```

or simply kill it:

```julia
PlotlyKaleido.kill_kaleido()
```

To enable LaTeX (using MathJax v2) in plots, use the keyword argument `mathjax`:
```julia
PlotlyKaleido.start(mathjax=true)  # start Kaleido server with MathJax enabled
```

## Windows Note
Many people on Windows have issues with the latest (0.2.1) version of the Kaleido library (see for example [discourse](https://discourse.julialang.org/t/plotlyjs-causes-errors-cant-figure-out-how-to-use-plotlylight-how-to-use-plotly-from-julia/108853/29), [this PR's comment](https://github.com/JuliaPlots/PlotlyKaleido.jl/pull/17#issuecomment-1969325440) and [this issue](https://github.com/plotly/Kaleido/issues/134) on the Kaleido repository).

Many people have succesfully fixed this problem on windows by downgrading the kaleido library to version 0.1.0 (see [the previously mentioned issue](https://github.com/plotly/Kaleido/issues/134)). If you experience issues with `PlotlyKaleido.start()` hanging on windows, you may want try adding `Kaledido_jll@v0.1` explicitly to your project environment to fix this. You can do so by either doing:
```julia
add Kaleido_jll@v0.1
```
inside the REPL package enviornment, or by calling the following code in the REPL directly:
```julia
begin
    import Pkg
    Pkg.add(; name = "Kaleido_jll", version = "0.1")
end

The package will now default to using an explicitly provided version of Kaleido 0.1 on Windows systems without requiring to explicitly fix the version of `Kaleido_jll` in your project environment.

To disable this automatic fallback, you can set `PlotlyKaleido.USE_KALEIDO_FALLBACK[] = false`.
```
