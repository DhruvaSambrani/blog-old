using Markdown

function hfun_listposts()
    posts = readdir("posts") |> reverse .|> splitext .|> x->first(x)
    return join(map(filter(i -> i!="index", posts)) do filename
        "- $(filename) - [$(pagevar("posts/$(filename)", "post_title"))]($(filename))"
    end, "\n") |> Markdown.parse |> html
end

function hfun_m1fill(vname)
  var = vname[1]
  return pagevar("index", var)
end

function lx_baz(com, _)
  # keep this first line
  brace_content = Franklin.content(com.braces[1]) # input string
  # do whatever you want here
  return uppercase(brace_content)
end
