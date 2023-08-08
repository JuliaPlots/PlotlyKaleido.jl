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
