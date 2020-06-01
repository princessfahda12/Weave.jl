# TODO:
# - 1. Improve argument handling
# - 2. Update code to use UnPack.jl to make it more readable
# - 3. Export new interface
# - 4. Document Interface

using Mustache, Highlights, .WeaveMarkdown, Markdown, Dates, Printf
using REPL.REPLCompletions: latex_symbols


const FORMATS = Dict{String,WeaveFormat}()

# TODO: do some assertion for necessary fields of `format`
register_format!(format_name::AbstractString, format::WeaveFormat) = push!(FORMATS, format_name => format)
register_format!(_, format) = error("Format needs to be a subtype of WeaveFormat.")

set_rendering_options!(doc; kwargs...) = set_rendering_options!(doc.format; kwargs...)

function render_doc(doc)
    docformat = doc.format

    restore_header!(doc)

    lines = map(copy(doc.chunks)) do chunk
        format_chunk(chunk, docformat)
    end
    body = join(lines, '\n')

    return render_doc(docformat, body, doc)
end

@static VERSION < v"1.1" && begin
macro kwdef(expr)
    expr = macroexpand(__module__, expr) # to expand @static
    expr isa Expr && expr.head === :struct || error("Invalid usage of @kwdef")
    T = expr.args[2]
    if T isa Expr && T.head === :<:
        T = T.args[1]
    end

    params_ex = Expr(:parameters)
    call_args = Any[]

    Base._kwdef!(expr.args[3], params_ex.args, call_args)
    # Only define a constructor if the type has fields, otherwise we'll get a stack
    # overflow on construction
    if !isempty(params_ex.args)
        if T isa Symbol
            kwdefs = :(($(esc(T)))($params_ex) = ($(esc(T)))($(call_args...)))
        elseif T isa Expr && T.head === :curly
            # if T == S{A<:AA,B<:BB}, define two methods
            #   S(...) = ...
            #   S{A,B}(...) where {A<:AA,B<:BB} = ...
            S = T.args[1]
            P = T.args[2:end]
            Q = [U isa Expr && U.head === :<: ? U.args[1] : U for U in P]
            SQ = :($S{$(Q...)})
            kwdefs = quote
                ($(esc(S)))($params_ex) =($(esc(S)))($(call_args...))
                ($(esc(SQ)))($params_ex) where {$(esc.(P)...)} =
                    ($(esc(SQ)))($(call_args...))
            end
        else
            error("Invalid usage of @kwdef")
        end
    else
        kwdefs = nothing
    end
    quote
        Base.@__doc__($(esc(expr)))
        $kwdefs
    end
end
end

include("common.jl")
include("htmlformats.jl")
include("texformats.jl")
include("variousformats.jl")
include("markdownformats.jl")
