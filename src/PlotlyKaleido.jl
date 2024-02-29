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

const _mathjax_url_path = "https://cdnjs.cloudflare.com/ajax/libs/mathjax"
const _mathjax_last_version = v"2.7.9"

kill_kaleido() = is_running() && (kill(P.proc); wait(P.proc))

is_running() = isdefined(P, :proc) && isopen(P.stdin) && process_running(P.proc)

restart(; kwargs...) = (kill_kaleido(); start(; kwargs...))

#=
This function checks if the kaleido.cmd has only read permission, and if so,
creates a temporary kaleido.cmd that directly calls the binary to bypass
permission errors
=#
function maybe_copy_deps(dirpath = pwd())
    Sys.iswindows() || return
    basedir = Kaleido_jll.artifact_dir
    js_path = joinpath("js", "kaleido_scopes.js")
    local_js = joinpath(dirpath, js_path)
    mkpath(local_js |> dirname) # Ensure the js directory exists
    artifact_js = joinpath(basedir, js_path)
    # Copy js
    cp(artifact_js, local_js; force = true)
    # Copy the version
    cp(joinpath(basedir, "version"), joinpath(dirpath, "version"); force = true)
    return
end

function start(;
    plotly_version = missing,
    mathjax = missing,
    mathjax_version::VersionNumber = _mathjax_last_version,
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
    kproc = cd(Sys.iswindows() ? mktempdir() : Kaleido_jll.artifact_dir) do
        maybe_copy_deps(pwd()) # This will do nothing outside of windows
        run(pipeline(BIN, stdin = kstdin, stdout = kstdout, stderr = kstderr), wait = false)
    end

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
