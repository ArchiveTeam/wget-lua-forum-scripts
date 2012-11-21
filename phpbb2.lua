--[[
Download script for phpBB2 forums.
2012.09.25

This script walks the forum pages: from forum index, to forums, to threads.
It will also download the member pages.

You need Wget+Lua to run this script.

Run Wget with seed URLs that point to the forum you want to download.
Start with the URL to the RSS feed (to get a session cookie), then give
the index page without and with index.php. For example:
 http://www.phpbb.com/community/rss.php
 http://www.phpbb.com/community/
 http://www.phpbb.com/community/index.php

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
    --lua-script=phpbb.lua \
    --warc-max-size=200M \
    --warc-header="operator: Archive Team" \
    --warc-file=phpbb.com-community-$( date +'%Y%m%d' ) \
    "http://www.phpbb.com/community/rss.php" \
    "http://www.phpbb.com/community/" \
    "http://www.phpbb.com/community/index.php"

--]]

read_file = function(file)
  local f = io.open(file)
  local data = f:read("*all")
  f:close()
  return data
end

url_count = 0

wget.callbacks.get_urls = function(file, url, is_css, iri)
  local urls = {}

  -- progress message
  url_count = url_count + 1
  if url_count % 25 == 0 then
    print(" - Downloaded "..url_count.." URLs")
  end

  base = string.match(url, "(http://.+)/index%.php")
  if base then
    -- list of forums
    html = read_file(file)

    -- forums
    for f in string.gmatch(html, "viewforum%.php%?f=(%d+)") do
      table.insert(urls, { url=(base.."/viewforum.php?f="..f), link_expect_html=1 })
    end

    return urls
  end

  base, forum_id = string.match(url, "(http://.+)/viewforum%.php%?f=(%d+)")
  if base then
    -- forum index
    html = read_file(file)

    -- pages
    for start in string.gmatch(html, "viewforum%.php%?f="..forum_id.."&amp;topicdays=0&amp;start=(%d+)") do
      table.insert(urls, { url=(base.."/viewforum.php?f="..forum_id.."&topicdays=0&start="..start), link_expect_html=1 })
    end

    -- topics
    for topic_id in string.gmatch(html, "viewtopic%.php%?t=(%d+)") do
      table.insert(urls, { url=(base.."/viewtopic.php?t="..topic_id), link_expect_html=1 })
      -- first page
      table.insert(urls, { url=(base.."/viewtopic.php?t="..topic_id.."&postdays=0&postorder=asc&start=0"), link_expect_html=1 })
    end

    return urls
  end

  base, topic_id = string.match(url, "(http://.+)/viewtopic%.php%?t=(%d+)")
  if base then
    -- topic
    html = read_file(file)

    -- pages
    for start in string.gmatch(html, "viewtopic%.php%?t="..topic_id.."&amp;postdays=0&amp;postorder=asc&amp;start=(%d+)") do
      table.insert(urls, { url=(base.."/viewtopic.php?t="..topic_id.."&postdays=0&postorder=asc&start="..start), link_expect_html=1 })
    end

    -- profiles
    for u in string.gmatch(html, "profile%.php%?mode=viewprofile&amp;u=(%d+)") do
      table.insert(urls, { url=(base.."/profile.php?mode=viewprofile&u="..u), link_expect_html=1 })
    end

    return urls
  end
  
  return {}
end

