using Markdown

_get_date(filename) = split(filename, " ")[1]
_get_title(filename) = pagevar("posts/$(filename)", "post_title")
function _get_posts()
    fns = readdir("posts") .|> splitext .|> first
    filter(!startswith("index"), fns)
end
function _get_summary(fn)
    lines = first(readlines("posts/"*fn*".md"), 15)
    cont = join(lines, "\n")
    if length(lines) == 15
        string(cont, "\n\n@@readmore\n[… Read more](posts/$(fn))\n@@")
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
    deets = map(recent_posts) do fn
        text = fd2html(_get_summary(fn), internal=true)
        title = _get_title(fn)
        date = _get_date(fn)
        """<details class="style2"><summary>$(title) on $(date)</summary><div class="details-content">$(text)</div></details>"""
    end
    return join(deets, "\n")
end

