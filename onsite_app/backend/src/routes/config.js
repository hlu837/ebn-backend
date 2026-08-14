// Hands runtime configuration to the frontend so secrets like map API
// keys never have to be hardcoded into the Flutter app's source. The
// frontend calls GET /api/config/map once on startup and caches the
// result in memory for the session.
//
// Note: a Gebeta Maps key is a client-facing map key (the same one you'd
// pass to a browser JS SDK), not a backend-only secret like a DB password
// — serving it to an authenticated client is normal practice for map
// providers. It still lives only in .env, never in committed source.

const express = require('express');

const router = express.Router();

// Addis Ababa — used as the map's default center when the app doesn't
// have a more specific location to center on yet.
const DEFAULT_CENTER = { latitude: 9.0192, longitude: 38.7525 };

router.get('/map', (req, res) => {
  const apiKey = process.env.GEBETA_MAPS_API_KEY;
  if (!apiKey) {
    return res.status(503).json({
      error:
        'GEBETA_MAPS_API_KEY is not configured on the server — add it to .env (see .env.example) to enable the live map.',
    });
  }

  res.json({
    provider: 'openfreemap',
    apiKey: apiKey || 'public',
    styleUrl: 'https://tiles.openfreemap.org/styles/liberty',
    defaultCenter: DEFAULT_CENTER,
  });
});

module.exports = { router };
