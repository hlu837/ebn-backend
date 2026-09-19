// One-time backfill: generates `thumbnail_url` for every asset row that
// has an `image_url` but no thumbnail yet (i.e. every row that existed
// before migration 092_assets_thumbnail_url.sql). New/edited rows get
// their thumbnail generated automatically going forward — see
// models/assets.js `create`/`update` — this script only needs to run
// once, right after applying that migration.
//
// Usage: npm run backfill-thumbnails

require('dotenv').config();
const { pool } = require('../src/db');
const { makeThumbnailDataUrl } = require('../src/utils/thumbnail');

async function main() {
  const { rows } = await pool.query(
    `SELECT id, image_url FROM assets WHERE image_url IS NOT NULL AND thumbnail_url IS NULL`
  );

  if (!rows.length) {
    console.log('Nothing to backfill — every asset with an image already has a thumbnail.');
    return;
  }

  console.log(`Backfilling thumbnails for ${rows.length} asset(s)...`);
  let ok = 0;
  let failed = 0;
  for (const row of rows) {
    try {
      const thumbnail = await makeThumbnailDataUrl(row.image_url);
      await pool.query(`UPDATE assets SET thumbnail_url = $2 WHERE id = $1`, [row.id, thumbnail]);
      ok += 1;
    } catch (err) {
      failed += 1;
      console.error(`  Failed for asset ${row.id}:`, err.message);
    }
  }
  console.log(`Done. ${ok} succeeded, ${failed} failed.`);
}

main()
  .catch((err) => {
    console.error('Backfill failed:', err);
    process.exitCode = 1;
  })
  .finally(() => pool.end());
