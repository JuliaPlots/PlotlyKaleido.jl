module PlotlyKaleido

using JSON: JSON
using Base64
using Kaleido_jll

export savefig

#-----------------------------------------------------------------------------# Kaleido Process
mutable struct Pipes
    stdin::Pipe
    stdout::Pipe
    stderr::Pipe
    proc::Base.Process
    Pipes() = new()
end

const P = Pipes()

kill_kaleido() = is_running() && kill(P.proc)

is_running() = isdefined(P, :proc) && isopen(P.stdin) && process_running(P.proc)

restart(;kwargs...) = (kill_kaleido(); sleep(0.1); start(;kwargs...))

function start(;plotly_version = missing, kwargs...)
    is_running() && return
    cmd = joinpath(Kaleido_jll.artifact_dir, "kaleido" * (Sys.iswindows() ? ".cmd" : ""))
    basic_cmds = [cmd, "plotly"]
    chromium_flags = ["--disable-gpu", Sys.isapple() ? "--single-process" : "--no-sandbox"]
    extra_flags = if plotly_version === missing
        (;
            kwargs...
        )
    else
        # We create a plotlyjs flag pointing at the specified plotly version
        (;
            plotlyjs = "https://cdn.plot.ly/plotly-$(plotly_version).min.js",
            kwargs...
        )
    end
    # Taken inspiration from https://github.com/plotly/Kaleido/blob/3b590b563385567f257db8ff27adae1adf77821f/repos/kaleido/py/kaleido/scopes/base.py#L116-L141
    user_flags = String[]
    for (k,v) in pairs(extra_flags)
        flag_name = replace(string(k), "_" => "-")
        if v isa Bool
            v && push!(user_flags, "--$flag_name")
        else
            push!(user_flags, "--$flag_name=$v")
        end
    end
    BIN  = Cmd(vcat(basic_cmds, chromium_flags, user_flags))

    kstdin = Pipe()
    kstdout = Pipe()
    kstderr = Pipe()
    kproc = run(pipeline(BIN, stdin=kstdin, stdout=kstdout, stderr=kstderr), wait=false)

    process_running(kproc) || error("There was a problem starting up kaleido.")
    close(kstdout.in)
    close(kstderr.in)
    close(kstdin.out)
    Base.start_reading(kstderr.out)

    global P
    P.stdin = kstdin
    P.stdout = kstdout
    P.stderr = kstderr
    P.proc = kproc

    res = readline(P.stdout)  # {"code": 0, "message": "Success", "result": null, "version": "0.2.1"}
    length(res) == 0 && error("Kaleido startup failed.")
    code = JSON.parse(res)["code"]
    code == 0 || error("Kaleido startup failed with code $code.")
    return
end


#-----------------------------------------------------------------------------# save
const ALL_FORMATS = ["png", "jpeg", "webp", "svg", "pdf", "eps", "json"]
const TEXT_FORMATS = ["svg", "json", "eps"]


function save_payload(io::IO, payload::AbstractString, format::AbstractString)
    format in ALL_FORMATS || error("Unknown format $format. Expected one of $ALL_FORMATS")

    bytes = transcode(UInt8, payload)
    write(P.stdin, bytes)
    write(P.stdin, transcode(UInt8, "\n"))
    flush(P.stdin)

    res = readline(P.stdout)
    obj = JSON.parse(res)
    obj["code"] == 0 || error("Transform failed: $res")

    img = String(obj["result"])

    # base64 decode if needed, otherwise transcode to vector of byte
    bytes = format in TEXT_FORMATS ? transcode(UInt8, img) : base64decode(img)

    write(io, bytes)
end

function savefig(io::IO, plot; height=500, width=700, scale=1, format="png")
    payload = JSON.json((; height, width, scale, format, data=plot))
    save_payload(io, payload, format)
end

function savefig(filename::AbstractString, plot; kw...)
    format = get(kw, :format, split(filename, '.')[end])
    open(io -> savefig(io, plot; format, kw...), filename, "w")
    filename
end

savefig(plot, filename::AbstractString; kw...) = savefig(filename, plot; kw...)

end # module Kaleido
