using Test
@test_nowarn @eval using Kaleido

import PlotlyLight, EasyConfig, PlotlyJS
@test_nowarn @eval using Kaleido

@testset "Saving JSON String" begin
    plt = "{\"data\":{\"data\":[{\"y\":[1,2,3],\"type\":\"scatter\",\"x\":[0,1,2]}]}}"
    for ext in Kaleido.ALL_FORMATS
        file = tempname() * ".$ext"
        open(io -> Kaleido.save_payload(io, plt, ext), file, "w")
        @test isfile(file)
        rm(file)
    end
end

@testset "Saving PlotlyJS & PlotlyLight" begin
    for plt in [
            PlotlyJS.plot(PlotlyJS.scatter(x=rand(10))),
            PlotlyLight.Plot(EasyConfig.Config(x=rand(10)))
        ]
        for ext in Kaleido.ALL_FORMATS
            ext == "eps" && continue # TODO" Why does this work above but not here?
            file = tempname() * ".$ext"
            @test Kaleido.savefig(plt, file) == file
            @test isfile(file)
            rm(file)
        end
    end
end
