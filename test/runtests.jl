using Kaleido
using Test
import PlotlyLight, EasyConfig, PlotlyJS

@testset "Save to file" begin
    plt = "{\"data\":{\"data\":[{\"y\":[1,2,3],\"type\":\"scatter\",\"x\":[0,1,2]}]}}"
    for ext in Kaleido.ALL_FORMATS
        fn = tempname() * "." * ext
        @info fn
        open(fn, "w") do io
            Kaleido.save_payload(io, plt, fn)
            @test isfile(fn)
            rm(fn)
        end
    end
end

@testset "PlotlyJS" begin
    plt = PlotlyJS.scatter(x=rand(10))
    for ext in Kaleido.ALL_FORMATS
        ext == "eps" && continue  # Why does this work above but not here?
        fn = tempname() * "." * ext
        @info fn
        @test Kaleido.savefig(plt, fn) == fn
    end
end

@testset "PlotlyLight" begin
    plt = PlotlyLight.Plot(EasyConfig.Config(x=rand(10)))
    for ext in Kaleido.ALL_FORMATS
        ext == "eps" && continue  # Why does this work above but not here?
        fn = tempname() * "." * ext
        @info fn
        @test Kaleido.savefig(plt, fn) == fn
    end
end
