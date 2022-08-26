using Test
@test_nowarn @eval using Kaleido

@testset "Save to file" begin
    plt = "{\"data\":{\"data\":[{\"y\":[1,2,3],\"type\":\"scatter\",\"x\":[0,1,2]}]}}"
    for ext in Kaleido.ALL_FORMATS
        fn = tempname() * "." * ext
        @show fn
        @test Kaleido.savefig(plt, fn) == fn
        @test isfile(fn)
        rm(fn)
    end
end
