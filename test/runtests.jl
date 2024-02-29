using Test
import Pkg
if Sys.iswindows()
    # Fix kaleido tests on windows due to Kaleido_jll@v0.2.1 hanging
    Pkg.add(;name = "Kaleido_jll", version = "0.1")
end
@test_nowarn @eval using PlotlyKaleido

@testset "Start" begin
    @test_nowarn PlotlyKaleido.start()
    @test PlotlyKaleido.is_running()
end


import PlotlyLight, EasyConfig, PlotlyJS

@testset "Saving JSON String" begin
    plt = "{\"data\":{\"data\":[{\"y\":[1,2,3],\"type\":\"scatter\",\"x\":[0,1,2]}]}}"
    for ext in PlotlyKaleido.ALL_FORMATS
        file = tempname() * ".$ext"
        open(io -> PlotlyKaleido.save_payload(io, plt, ext), file, "w")
        @test isfile(file)
        @test filesize(file) > 0
        rm(file)
    end
end

@testset "Saving Base structures" begin
    plt0 = Dict(:data => [Dict(:x => [0, 1, 2], :type => "scatter", :y => [1, 2, 3])])
    for plt in (plt0, NamedTuple(plt0))
        for ext in PlotlyKaleido.ALL_FORMATS
            ext == "eps" && continue # TODO" Why does this work above but not here?
            file = tempname() * ".$ext"
            PlotlyKaleido.savefig(file, plt)
            @test isfile(file)
            @test filesize(file) > 0
            rm(file)
        end
    end
end

@testset "Saving PlotlyJS & PlotlyLight" begin
    for plt in [
        PlotlyJS.plot(PlotlyJS.scatter(x = rand(10))),
        PlotlyLight.Plot(EasyConfig.Config(x = rand(10))),
    ]
        for ext in PlotlyKaleido.ALL_FORMATS
            ext == "eps" && continue # TODO" Why does this work above but not here?
            file = tempname() * ".$ext"
            @test PlotlyKaleido.savefig(plt, file) == file
            @test isfile(file)
            @test filesize(file) > 0
            rm(file)
        end
    end
end

@testset "Shutdown" begin
    PlotlyKaleido.kill_kaleido()
    @test !PlotlyKaleido.is_running()

end
