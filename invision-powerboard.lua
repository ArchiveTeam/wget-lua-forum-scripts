--[[
Download script for older Invision Powerboard forums.
2012.10.27

This script walks the forum pages: from forum index, to forums, to threads.
It will also download the lofi version.

You need Wget+Lua to run this script.

Run Wget with seed URLs that point to the forum you want to download.
Start with the URL to the login page (to get a session cookie), then give
the index page without and with index.php. For example:
 http://example.com/index.php?act=Login
 http://example.com/
 http://example.com/index.php

Use --page-requisites --span-hosts, but do not use --mirror or --recursive.

Example command line:

./wget-warc-lua \
    --directory-prefix=files/ \
    --force-directories --adjust-extension \
    --user-agent="Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US) AppleWebKit/533.20.25 (KHTML, like Gecko) Version/5.0.4 Safari/533.20.27" \
    -nv -o files/wget.log \
    --page-requisites --span-hosts \
    -e "robots=off" \
    --keep-session-cookies --save-cookies=files/cookies.txt \
    --timeout=10 --tries=3 --waitretry=5 \
    --lua-script=invision-powerboard.lua \
    --warc-max-size=200M \
    --warc-header="operator: Archive Team" \
    --warc-file=example.com-forums-$( date +'%Y%m%d' ) \
    "http://example.com/index.php?act=Login" \
    "http://example.com/" \
    "http://example.com/index.php"

]]--

read_file = function(file)
  if file then
    local f = io.open(file)
    local data = f:read("*all")
    f:close()
    return data
  else
    return ""
  end
end

local url_count = 0

wget.callbacks.httploop_result = function(url, err, hstat)
  if err=="NEWLOCATION" and (string.match(url.url, "view=old") or string.match(url.url, "view=new")) then
    -- do not follow redirect to next/previous topic
    return wget.actions.EXIT
  else
    return wget.actions.NOTHING
  end
end

wget.callbacks.get_urls = function(file, url, is_css, iri)
  local urls = {}

  -- progress message
  url_count = url_count + 1
  if url_count % 50 == 0 then
    io.stdout:write("\r", "Downloaded "..url_count.." URLs")
    io.stdout:flush()
  end

  base = string.match(url, "(http://.+)/index%.php$")
  if base then
    -- forum index page
    html = read_file(file)

    -- index page
    table.insert(urls, { url=(base.."/index.php?act=idx"), link_expect_html=1 })

    -- lofi version
    table.insert(urls, { url=(base.."/lofiversion/"), link_expect_html=1 })
    table.insert(urls, { url=(base.."/lofiversion/index.php"), link_expect_html=1 })

    -- forums
    for f in string.gmatch(html, "index%.php%?showforum=(%d+)") do
      table.insert(urls, { url=(base.."/index.php?showforum="..f), link_expect_html=1 })
    end

    return urls
  end

  base, forum_id = string.match(url, "(http://.+)/index%.php%?showforum=(%d+)")
  if base then
    -- forum
    html = read_file(file)

    -- lofi version
    table.insert(urls, { url=(base.."/lofiversion/index.php?f"..forum_id..".html"), link_expect_html=1 })

    -- pages
    for prune_day, st in string.gmatch(html, "index%.php%?showforum="..forum_id.."&amp;prune_day=(%d+)&amp;sort_by=Z%-A&amp;sort_key=last_post&amp;topicfilter=all&amp;st=(%d+)") do
      table.insert(urls, { url=(base.."/index.php?showforum="..forum_id.."&prune_day="..prune_day.."&sort_by=Z-A&sort_key=last_post&topicfilter=all&st="..st), link_expect_html=1 })
    end

    -- topics
    for t in string.gmatch(html, "index%.php%?showtopic=(%d+)") do
      table.insert(urls, { url=(base.."/index.php?showtopic="..t), link_expect_html=1 })
    end

    return urls
  end

  base, topic_id = string.match(url, "(http://.+)/index%.php%?showtopic=(%d+)")
  if base then
    -- topic
    html = read_file(file)

    -- who posted
    table.insert(urls, { url=(base.."/index.php?act=Stats&CODE=who&t="..topic_id), link_expect_html=1 })

    -- lofi version
    table.insert(urls, { url=(base.."/lofiversion/index.php?t"..topic_id..".html"), link_expect_html=1 })

    -- new, old
    table.insert(urls, { url=(base.."/index.php?showtopic="..topic_id.."&view=old"), link_expect_html=1 })
    table.insert(urls, { url=(base.."/index.php?showtopic="..topic_id.."&view=new"), link_expect_html=1 })

    -- pages
    for st in string.gmatch(html, "index%.php%?showtopic="..topic_id.."&amp;st=(%d+)") do
      table.insert(urls, { url=(base.."/index.php?showtopic="..topic_id.."&st="..st), link_expect_html=1 })
    end

--  user pages are only available to logged-in users
--  -- users
--  for u in string.gmatch(html, "index%.php%?showuser=(%d+)") do
--    table.insert(urls, { url=(base.."/index.php?showuser="..u), link_expect_html=1 })
--  end

    return urls
  end

  base, forum_id = string.match(url, "(http://.+)/lofiversion/index%.php%?f(%d+)")
  if base then
    -- forum, lofi
    html = read_file(file)

    -- pages
    for st in string.gmatch(html, "lofiversion/index%.php%?f"..forum_id.."%-(%d+).html") do
      table.insert(urls, { url=(base.."/lofiversion/index.php?f"..forum_id.."-"..st..".html"), link_expect_html=1 })
    end

    return urls
  end

  base, topic_id = string.match(url, "(http://.+)/lofiversion/index%.php%?t(%d+)")
  if base then
    -- topic, lofi
    html = read_file(file)

    -- pages
    for st in string.gmatch(html, "lofiversion/index%.php%?t"..topic_id.."%-(%d+).html") do
      table.insert(urls, { url=(base.."/lofiversion/index.php?t"..topic_id.."-"..st..".html"), link_expect_html=1 })
    end

    return urls
  end

  return urls
end

