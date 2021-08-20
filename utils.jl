using Markdown

_get_date(filename) = split(filename, " ")[1]
_get_title(filename) = pagevar("posts/$(filename)", "post_title")
function _get_posts()
    fns = readdir("posts") .|> splitext .|> first
    filter(!startswith("index"), fns)
end
function _get_summary(fn)
    lines = first(readlines("posts/"*fn*".md"), 25)
    cont = join(lines, "\n")
    if length(lines) == 25
        string(cont, "\n\n[Read more](posts/$(fn))")
    else
        cont
    end
end

function hfun_listposts()
    posts = _get_posts()
    return join(map(posts) do fn
                    "- $(_get_date(fn)) - [$(_get_title(fn))]($(fn))"
    end, "\n") |> Markdown.parse |> html
end

function hfun_recents()
    posts = last(_get_posts(), 3)
    return "<ul>" * join(map(posts) do fn
        """<li class="sidebar-nav-recents"><a class="sidebar-nav-item {{ispage posts/$(fn)}}active{{end}}" href="/posts/$(fn)">$(_get_title(fn))</a></li>"""
    end, "\n") * "</ul>"
end
function hfun_recents_long()
    recent_posts = last(_get_posts(), 5)
    println(recent_posts)
    deets = map(recent_posts) do fn
        text = fd2html(_get_summary(fn), internal=true)
        title = _get_title(fn)
        date = _get_date(fn)
        "<details><summary>$(title) on $(date)</summary>$(text)</details>"
    end
    return join(deets, "\n")
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
