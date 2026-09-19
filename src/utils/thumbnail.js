const sharp = require('sharp');

// Small + heavily compressed on purpose: this only feeds the browse-feed
// list endpoint (GET /api/assets), which can return dozens/hundreds of
// listings in one response. Detail views and the agent's own
// edit/broker-scoped endpoints are untouched and keep the full-resolution
// original — see routes/assets.js and models/assets.js for the split.
const MAX_DIMENSION = 320;
const JPEG_QUALITY = 45;

const DATA_URL_RE = /^data:([^;]+);base64,(.+)$/s;

/**
 * Given whatever's stored in `image_url` (either a `data:<mime>;base64,...`
 * string produced by the app's picker, or a plain http(s) URL for anything
 * already hosted externally), returns a small re-encoded JPEG data URL
 * suitable for list/card thumbnails — or the original value unchanged if
 * it's not a data URL we can decode (a plain URL is already cheap to
 * fetch, nothing to shrink) or if decoding/resizing fails for any reason
 * (corrupt upload, unsupported format, etc — we never want a bad image to
 * take the whole listing feed down).
 */
async function makeThumbnailDataUrl(imageUrl) {
  if (!imageUrl || typeof imageUrl !== 'string') return imageUrl;
  const match = imageUrl.match(DATA_URL_RE);
  if (!match) return imageUrl; // plain hosted URL — nothing to do here

  try {
    const buffer = Buffer.from(match[2], 'base64');
    const resized = await sharp(buffer)
      .resize(MAX_DIMENSION, MAX_DIMENSION, { fit: 'inside', withoutEnlargement: true })
      .jpeg({ quality: JPEG_QUALITY })
      .toBuffer();
    return `data:image/jpeg;base64,${resized.toString('base64')}`;
  } catch (err) {
    console.warn('makeThumbnailDataUrl: failed to shrink image, falling back to original', err.message);
    return imageUrl;
  }
}

module.exports = { makeThumbnailDataUrl, MAX_DIMENSION, JPEG_QUALITY };
