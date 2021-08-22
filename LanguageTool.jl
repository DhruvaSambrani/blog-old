#! /usr/bin/env julia

using JSON
using HTTP
using REPL.TerminalMenus
using ArgParse

clear() = print("\u001Bc")

function display_match(TEXT, fix_range, message)
    clear()
    display_range = clamp(first(fix_range)-7, 1, length(TEXT)) : clamp(last(fix_range)+7, 1, length(TEXT))
    println(replace(TEXT[display_range], "\n" => " "))
    println(message)
end

function fix(TEXT, match)
    fix_range = match["offset"]+1 : match["offset"]+match["length"]
    display_match(TEXT, fix_range, match["message"])

    menu = string.(getindex.(match["replacements"], Ref("value")))
    user_response = request("Choose", RadioMenu(vcat(["Custom", "Ignore"], menu))) - 2
    if user_response == -1 # custom
        return readline(), fix_range
    elseif user_response == 0 # ignore
        return nothing, fix_range
    else
        return menu[user_response], fix_range
    end
end

function apply(TEXT, fixes)
    output = IOBuffer()
    wrotetill = 0
    for fixpair in fixes
        fix, fix_range = fixpair
        if isnothing(fix)
            fix = SubString(TEXT, first(fix_range), last(fix_range))
        end
        write(output, SubString(TEXT, wrotetill+1, first(fix_range)-1))
        write(output, fix)
        wrotetill = last(fix_range)
    end
    String(take!(output))
end

function post_apply(fixed, FILE, ISFILE)
    clear()
    println(fixed)

    FILENAME, EXT = splitext(FILE)
    DIR = dirname(FILE)
    fileops = ISFILE ? ["Backup and overwrite", "Overwrite"] : []
    response = request("All Errors fixed! How to continue?", RadioMenu(vcat(["New File", "Write to console"], fileops)))
    if response == 1
        println("Path to new file" * (ISFILE ? "(`%` => dirname(in-file), `^` => filename(in-file), `&` => ext(in-file)): " : ": "))
        newpath = replace(chomp(readline()), "%" => DIR, "^" => FILENAME, "&" => EXT)
        println("Saving to $(newpath). Will overwrite this path if exists. Continue? [Yn]: ")
        chomp(readline()) == "n" ? post_apply(fixed, FILE, ISFILE) : write(newpath, fixed)
    elseif response == 2
        clear()
        println(fixed)
    elseif response == 3
        mv(FILE, FILE*".bak")
    elseif response in [3, 4]
        write(FILE, fixed)
    end
end

function main(FILE, PORT, LTPATH, RUN_SERVER)
    TEXT = FILE
    ISFILE = isfile(TEXT)
    if ISFILE; TEXT = read(TEXT, String); end

    # start LT Server
    RUN_SERVER && run(`java java -cp $(LTPATH)languagetool-server.jar $(LTPATH)org.languagetool.server.HTTPServer --port $(PORT)`, wait=false)

    # Send Request
    resp = HTTP.request("POST", "http://localhost:$(PORT)/v2/check", [], "text=$(TEXT)&language=en-US")
    code, body = resp.status, String(resp.body)
    println(code)

    if code == 200
        response = JSON.Parser.parse(body)
        fixed = apply(TEXT, fix.(Ref(TEXT), response["matches"]))
        post_apply(fixed, FILE, ISFILE)
    else
        println("Some error, RESPONSE $(code)")
    end
end

s = ArgParseSettings(
        prog="LanguageTool",
        description="Checks grammar and spelling. Requires LanguageTool. 
Install from https://languagetool.org/download/LanguageTool-stable.zip.
LanguageTool documentation here - https://dev.languagetool.org/http-server"
    )
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
        action = :store_false
    "file"
        help = "File or text to check"
        required = true
end
parsed_args = parse_args(s)
println(parsed_args)

main(parsed_args["file"], parsed_args["port"], parsed_args["ltpath"], !parsed_args["no_run_server"])
