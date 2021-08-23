#! /usr/bin/env julia

using JSON
using HTTP
using REPL.TerminalMenus
using ArgParse
using REPL

clear() = print(stderr, "\u001Bc")

t = REPL.Terminals.TTYTerminal("tty", stdin, stderr, stderr)

function display_match(TEXT, fix_range, message)
    clear()
    df, dl = clamp(first(fix_range)-7, 1, length(TEXT)), clamp(last(fix_range)+7, 1, length(TEXT))
    println(stderr, replace(string(SubString(TEXT, thisind(TEXT, df), nextind(TEXT, dl))), "\n" => " "))
    println(stderr, message)
end

function fix(TEXT, LOCALWORDS, match)
    df = nextind(TEXT, 1, match["offset"])
    dl = nextind(TEXT, df, match["length"]-1)
    fix_range = df : dl
    display_match(TEXT, fix_range, match["message"])
    if TEXT[fix_range] in LOCALWORDS
        return nothing, fix_range
    end
    menu = string.(getindex.(match["replacements"], Ref("value")))
    user_response = request(t, "Choose", RadioMenu(String[["Add word", "Custom", "Ignore"]; menu])) - 3
    if user_response == -2
        push!(LOCALWORDS, TEXT[fix_range])
        return nothing, fix_range
    elseif user_response == -1 # custom
        return readline(), fix_range
    elseif user_response == 0 # ignore
        return nothing, fix_range
    else
        return menu[user_response], fix_range
    end
end

function apply(TEXT, fixes)
    println(stderr, "Applying fixes...")
    output = IOBuffer()
    wrotetill = 0
    for (idx, fixpair) in enumerate(fixes)
        clear()
        println(stderr, "Applying fix $(idx)")
        fix, fix_range = fixpair
        if isnothing(fix)
            fix = SubString(TEXT, first(fix_range), last(fix_range))
        end
        write(output, TEXT[nextind(TEXT, wrotetill) : prevind(TEXT, first(fix_range))])
        write(output, fix)
        wrotetill = thisind(TEXT, last(fix_range))
        t = String(take!(output))
        write(output, t)
        println(stderr, t)
        readline()
    end
    if thisind(TEXT, wrotetill) < lastindex(TEXT)
        write(output, SubString(TEXT, nextind(TEXT, wrotetill)))
    end
    String(take!(output))
end

r(DIR, FILENAME, EXT) = s->Dict('%' => DIR, '^' => FILENAME, '&' => EXT)[s]

function post_apply(fixed, FILE, ISFILE)
    clear()
    println(stderr, fixed)

    FILENAME, EXT = string.(splitext(basename(FILE)))
    DIR = string(dirname(FILE))
    _r = r(DIR, FILENAME, EXT)

    fileops = ISFILE ? ["Backup and overwrite", "Overwrite"] : []
    response = request(t, "All Errors fixed! How to continue?", RadioMenu(String[["New File", "Write to console"]; fileops]))
    if response == 1
        println(stderr, "Path to new file" * (ISFILE ? "(`%` => dirname(in-file), `^` => filename(in-file), `&` => ext(in-file)): " : ": "))
        newpath = replace(readline(), ['&', '^', '%']=>_r)
        println(stderr, "Saving to $(newpath). Will overwrite this path if exists. Continue? [Yn]: ")
        if readline() == "n" 
            post_apply(fixed, FILE, ISFILE)
        else
            write(newpath, fixed)
        end
    elseif response == 2
        clear()
        println(fixed)
    elseif response == 3
        mv(FILE, FILE*".bak")
        write(FILE, fixed)
    elseif response == 4
        write(FILE, fixed)
    end
end

function main(FILE, PORT, LTPATH, RUN_SERVER)
    TEXT = FILE
    ISFILE = isfile(TEXT)
    if ISFILE; TEXT = read(TEXT, String); end

    # start LT Server
    if RUN_SERVER
        println(stderr, "Attempting to run server from $(LTPATH) on PORT $(PORT)")
        run(`java java -cp $(LTPATH)languagetool-server.jar $(LTPATH)org.languagetool.server.HTTPServer --port $(PORT)`, wait=false)
    end

    LOCALWORDS = readlines(".dict")

    println(stderr, "POSTing Text and awaiting response")
    resp = HTTP.request("POST", "http://localhost:$(PORT)/v2/check", [], "text=$(TEXT)&language=en-US")
    code, body = resp.status, String(resp.body)
    println(stderr, "Response Code: $code")

    if code == 200
        response = JSON.Parser.parse(body)
        fixed = apply(TEXT, fix.(Ref(TEXT), Ref(LOCALWORDS), response["matches"]))
        post_apply(fixed, FILE, ISFILE)
        write(".dict", join(LOCALWORDS, "\n"))
    else
        println(stderr, "Some error, RESPONSE $(code)")
    end
end

s = ArgParseSettings(
        prog="LanguageTool",
        description="Checks grammar and spelling. Requires LanguageTool. 
Install from https://languagetool.org/download/LanguageTool-stable.zip.
LanguageTool documentation here - https://dev.languagetool.org/http-server
Beware of overwriting by piping (`>`) to existing file. An error can wipe data as no text is written to stdout until explicitly requested.
Preferably, save stdout to a variable and write that.")
@add_arg_table! s begin
    "--port", "-p"
        help = "Port where LanguageTool will run/is running"
        default = 8081
        arg_type = Int
    "--ltpath", "-l"
        help = "Directory where LanguageTool jar files reside"
        default = "~/.LanguageTool"
        arg_type = String 
    "--no_run_server", "-n"
        help = "Do not attempt to start a new server"
        action = :store_true
    "file"
        help = "File or text to check"
        required = true
end
parsed_args = parse_args(s)

main(parsed_args["file"], parsed_args["port"], parsed_args["ltpath"], !parsed_args["no_run_server"])
