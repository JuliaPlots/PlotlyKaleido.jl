# Kaleido.jl

**Kaleido.jl** is for saving [Plotly.js](https://plotly.com/javascript/) plots in a variety of formats using [Kaleido](https://github.com/plotly/Kaleido).

```julia
julia> Kaleido.ALL_FORMATS
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
using Kaleido

import PlotlyLight, EasyConfig, PlotlyJS

p1 = PlotlyLight.Plot(EasyConfig.Config(x = rand(10)))

p2 = PlotlyJS.plot(PlotlyJS.scatter(x = rand(10)))

# Kaleido is agnostic about which package you use to make Plotly plots!
Kaleido.savefig(p1, "plot1.png")
Kaleido.savefig(p2, "plot2.png")
```
