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

restart() = (kill_kaleido(); start())

function start()
    is_running() && return

    cmd = joinpath(Kaleido_jll.artifact_dir, "kaleido" * (Sys.iswindows() ? ".cmd" : ""))
    BIN = Sys.isapple() ? `$(cmd) plotly --disable-gpu --single-process` : `$(cmd) plotly --disable-gpu --no-sandbox`

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
