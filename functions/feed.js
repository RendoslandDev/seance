// Builds the Watch feed: the latest uploads from every channel in
// channels.json, newest first. YouTube's public RSS feeds need no API key and
// no quota, but browsers can't read them cross-origin — so the web app gets
// them through the `videos` function (index.js), and this file can also write
// the offline snapshot the app ships with:
//
//   node functions/feed.js --snapshot   # -> assets/data/videos_snapshot.json

const config = require("./channels.json");

const decode = (s) =>
  s
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&amp;/g, "&");

const tag = (xml, name) => {
  const m = xml.match(new RegExp(`<${name}[^>]*>([\\s\\S]*?)</${name}>`));
  return m ? decode(m[1].trim()) : "";
};

function parseFeed(xml, channel) {
  return xml
    .split("<entry>")
    .slice(1)
    .map((entry) => {
      const description = tag(entry, "media:description");
      return {
        id: tag(entry, "yt:videoId"),
        title: tag(entry, "title"),
        channel: channel.name,
        channelId: channel.id,
        category: channel.category,
        published: tag(entry, "published"),
        description:
          description.length > 280
            ? description.slice(0, 277).trimEnd() + "…"
            : description,
        // Shorts share the feed; keep long-form teaching only.
        short: /<link[^>]+href="[^"]*\/shorts\//.test(entry),
      };
    })
    .filter((v) => v.id && !v.short)
    .map(({ short, ...v }) => v);
}

async function fetchChannel(channel) {
  const url = `https://www.youtube.com/feeds/videos.xml?channel_id=${channel.id}`;
  const res = await fetch(url, { signal: AbortSignal.timeout(8000) });
  if (!res.ok) throw new Error(`${channel.name}: HTTP ${res.status}`);
  return parseFeed(await res.text(), channel);
}

async function buildFeed() {
  const results = await Promise.allSettled(config.channels.map(fetchChannel));
  const videos = results
    .filter((r) => r.status === "fulfilled")
    .flatMap((r) => r.value)
    .sort((a, b) => b.published.localeCompare(a.published));
  return {
    updatedAt: new Date().toISOString(),
    categories: config.categories,
    channels: config.channels,
    videos,
  };
}

module.exports = { buildFeed, parseFeed };

if (require.main === module) {
  buildFeed().then((feed) => {
    const json = JSON.stringify(feed);
    if (process.argv.includes("--snapshot")) {
      const path = require("path");
      const out = path.join(__dirname, "..", "assets", "data", "videos_snapshot.json");
      require("fs").writeFileSync(out, json);
      console.log(`${feed.videos.length} videos from ${feed.channels.length} channels -> ${out}`);
    } else {
      process.stdout.write(json);
    }
  });
}
