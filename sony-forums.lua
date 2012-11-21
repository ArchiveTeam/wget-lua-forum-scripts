--[[
Download script for the forums on http://forums.station.sony.com/.
2012.09.19

This script walks the forum pages: from forum index, to forums, to threads.
It will also download the member pages.

You need Wget+Lua to run this script.

Run Wget with seed URLs that point to the forum you want to download.
For example, start with these two URLs to download the Vanguard forums:
 http://forums.station.sony.com/vg/
 http://forums.station.sony.com/vg/forums/list.m

Use --page-requisites --span-hosts, but do not use --mirror or --recursive.

Example command line:

./wget-warc-lua \
    --directory-prefix=files/ \
    --force-directories --adjust-extension \
    --user-agent="Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US) AppleWebKit/533.20.25 (KHTML, like Gecko) Version/5.0.4 Safari/533.20.27" \
    -nv -o files/wget.log \
    --page-requisites --span-hosts \
    -e "robots=off" \
    --timeout=10 --tries=3 --waitretry=5 \
    --lua-script=sony-forums.lua \
    --warc-max-size=200M \
    --warc-header="operator: Archive Team" \
    --warc-file=forums.station.sony.com-vanguard-$( date +'%Y%m%d' ) \
    http://forums.station.sony.com/vg/ \
    http://forums.station.sony.com/vg/forums/list.m

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

  base = string.match(url, "(http://.+)/forums/list%.m")
  if base then
    -- list of forums
    html = read_file(file)

    -- categories
    for c in string.gmatch(html, "forums/list%.m%?category_id=(%d+)") do
      table.insert(urls, { url=(base.."/forums/list.m?category_id="..c), link_expect_html=1 })
    end

    -- forums
    for f in string.gmatch(html, "forums/show%.m%?forum_id=(%d+)") do
      table.insert(urls, { url=(base.."/forums/show.m?forum_id="..f), link_expect_html=1 })
    end

    -- member listing
    table.insert(urls, { url=(base.."/user/list.m"), link_expect_html=1 })

    -- recent topics
    table.insert(urls, { url=(base.."/recentTopics/list.m"), link_expect_html=1 })

    return urls
  end

  base = string.match(url, "(http://.+)/user/list%.m")
  if base then
    -- member listing
    html = read_file(file)

    -- pages
    for start in string.gmatch(html, "user/list%.m%?start=(%d+)") do
      table.insert(urls, { url=(base.."/user/list.m?start="..start), link_expect_html=1 })
    end

    -- members
    for user_id in string.gmatch(html, "user/profile%.m%?user_id=(%d+)") do
      table.insert(urls, { url=(base.."/user/profile.m?user_id="..user_id), link_expect_html=1 })
    end

    return urls
  end

  base, forum_id = string.match(url, "(http://.+)/forums/show%.m%?forum_id=(%d+)")
  if not base then
    base, forum_id = string.match(url, "(http://.+)/forums/show%.m%?start=(%d+)&forum_id=(%d+)")
  end
  if base then
    -- forum index
    html = read_file(file)

    -- pages
    for start in string.gmatch(html, "forums/show%.m%?start=(%d+)&forum_id="..forum_id) do
      table.insert(urls, { url=(base.."/forums/show.m?start="..start.."&forum_id="..forum_id), link_expect_html=1 })
    end

    -- topics
    for topic_id in string.gmatch(html, "posts/list%.m%?topic_id=(%d+)") do
      table.insert(urls, { url=(base.."/posts/list.m?topic_id="..topic_id), link_expect_html=1 })
    end

    return urls
  end

  base, topic_id = string.match(url, "(http://.+)/posts/list%.m%?topic_id=(%d+)")
  if not base then
    base, topic_id = string.match(url, "(http://.+)/posts/list%.m%?start=(%d+)&topic_id=(%d+)")
  end
  if base then
    -- topic
    html = read_file(file)

    -- pages
    for start in string.gmatch(html, "list%.m%?start=(%d+)&topic_id="..topic_id) do
      table.insert(urls, { url=(base.."/posts/list.m?start="..start.."&topic_id="..topic_id), link_expect_html=1 })
    end

    return urls
  end
  
  return {}
end

