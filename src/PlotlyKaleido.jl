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
    error_msg::String
    Pipes() = new()
end

const P = Pipes()

const _mathjax_url_path = "https://cdnjs.cloudflare.com/ajax/libs/mathjax"
const _mathjax_last_version = v"2.7.9"

haserror() = !isempty(P.error_msg)
function seterror(s::String)
    P.error_msg = s
    @error "$(s)"
    kill_kaleido()
    return nothing
end

kill_kaleido() = is_running() && (kill(P.proc); wait(P.proc))

is_running() = isdefined(P, :proc) && isopen(P.stdin) && process_running(P.proc)

restart(; kwargs...) = (kill_kaleido(); start(; kwargs...))

# The content of this function is inspired from https://discourse.julialang.org/t/readline-with-default-value-if-no-input-after-timeout/100388/2?u=disberd
function readline_noblock(io; timeout = 10)
    msg = Channel{String}(1)

    task = Task() do
        try
            put!(msg, readline(io))
        catch
            put!(msg, "Stopped")
        end
    end

    interrupter = Task() do
        sleep(timeout)
        if !istaskdone(task)
            Base.throwto(task, InterruptException())
        end
    end

    schedule(interrupter)
    schedule(task)
    wait(task)
    kaleido_version = read(joinpath(Kaleido_jll.artifact_dir, "version"), String)
    out = take!(msg)
    out === "Stopped" && seterror("It looks like the Kaleido (version $(kaleido_version)) process is hanging.
If you are on Windows this might be caused by known problems with Kaleido v0.2 on Windows.
You might want to try forcing a downgrade of the kaleido library to 0.1.
Check the Package Readme at https://github.com/JuliaPlots/PlotlyKaleido.jl/tree/main#windows-note for more details.

If you think this is not your case, you might try using a longer timeout to check if the process is not responding (defaults to 10 seconds) by passing the desired value in seconds using the `timeout` kwarg when calling `PlotlyKaleido.start` or `PlotlyKaleido.restart`")
    return out
end

function start(;
    plotly_version = missing,
    mathjax = missing,
    mathjax_version::VersionNumber = _mathjax_last_version,
    timeout = 10,
    kwargs...,
)
    is_running() && return
    # The kaleido executable must be ran from the artifact directory
    BIN = Cmd(kaleido(); dir = Kaleido_jll.artifact_dir)
    # We push the mandatory plotly flag
    push!(BIN.exec, "plotly")
    chromium_flags = ["--disable-gpu", Sys.isapple() ? "--single-process" : "--no-sandbox"]
    extra_flags = if plotly_version === missing
        (; kwargs...)
    else
        # We create a plotlyjs flag pointing at the specified plotly version
        (; plotlyjs = "https://cdn.plot.ly/plotly-$(plotly_version).min.js", kwargs...)
    end
    if !(mathjax === missing)
        if mathjax_version > _mathjax_last_version
            error(
                "The given mathjax version ($(mathjax_version)) is greater than the last supported version ($(_mathjax_last_version)) of Kaleido.",
            )
        end
        if mathjax isa Bool && mathjax
            push!(
                chromium_flags,
                "--mathjax=$(_mathjax_url_path)/$(mathjax_version)/MathJax.js",
            )
        elseif mathjax isa String
            # We expect the keyword argument to be a valid URL or similar, else error "Kaleido startup failed with code 1".
            push!(chromium_flags, "--mathjax=$(mathjax)")
        else
            @warn """The value of the provided argument
                    mathjax=$(mathjax)
                  is neither a Bool nor a String and has been ignored."""
        end
    end
    # Taken inspiration from https://github.com/plotly/Kaleido/blob/3b590b563385567f257db8ff27adae1adf77821f/repos/kaleido/py/kaleido/scopes/base.py#L116-L141
    user_flags = String[]
    for (k, v) in pairs(extra_flags)
        flag_name = replace(string(k), "_" => "-")
        if v isa Bool
            v && push!(user_flags, "--$flag_name")
        else
            push!(user_flags, "--$flag_name=$v")
        end
    end
    # We add the flags to the BIN
    append!(BIN.exec, chromium_flags, extra_flags)

    kstdin = Pipe()
    kstdout = Pipe()
    kstderr = Pipe()
    kproc = 
        run(pipeline(BIN, stdin = kstdin, stdout = kstdout, stderr = kstderr), wait = false)

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
    P.error_msg = ""

    res = readline_noblock(P.stdout; timeout)  # {"code": 0, "message": "Success", "result": null, "version": "0.2.1"}
    length(res) == 0 && seterror("Kaleido startup failed.")
    if !haserror()
        code = JSON.parse(res)["code"]
        code == 0 || seterror("Kaleido startup failed with code $code.")
    end
    return
end


#-----------------------------------------------------------------------------# save
const ALL_FORMATS = ["png", "jpeg", "webp", "svg", "pdf", "eps", "json"]
const TEXT_FORMATS = ["svg", "json", "eps"]


function save_payload(io::IO, payload::AbstractString, format::AbstractString)
    haserror() && error(P.error_msg)
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

function savefig(io::IO, plot; height = 500, width = 700, scale = 1, format = "png")
    payload = JSON.json((; height, width, scale, format, data = plot))
    save_payload(io, payload, format)
end

function savefig(
    io::IO,
    plot::AbstractString;
    height = 500,
    width = 700,
    scale = 1,
    format = "png",
)
    payload = "{\"width\":$width,\"height\":$height,\"scale\":$scale,\"data\": $plot}"
    save_payload(io, payload, format)
end

function savefig(filename::AbstractString, plot; kw...)
    format = get(kw, :format, split(filename, '.')[end])
    open(io -> savefig(io, plot; format, kw...), filename, "w")
    filename
end

savefig(plot, filename::AbstractString; kw...) = savefig(filename, plot; kw...)

end # module Kaleido
