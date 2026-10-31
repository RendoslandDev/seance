const { onRequest } = require("firebase-functions/v2/https");
const { buildFeed } = require("./feed");

// GET /api/videos (via the Hosting rewrite in firebase.json).
// Cached at Firebase Hosting's CDN for 15 minutes, so YouTube is asked at most
// a few times an hour no matter how many people are watching.
exports.videos = onRequest(
  { region: "us-central1", memory: "256MiB", timeoutSeconds: 30, cors: true },
  async (req, res) => {
    try {
      const feed = await buildFeed();
      res.set("Cache-Control", "public, max-age=300, s-maxage=900");
      res.json(feed);
    } catch (e) {
      console.error(e);
      res.status(502).json({ error: "feed unavailable" });
    }
  },
);
