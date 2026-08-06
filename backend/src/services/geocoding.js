// Turns a manually typed address into coordinates so it can be used the
// same way GPS coordinates are — for nearby-agent matching. Uses Google's
// Geocoding API; requires GEOCODING_API_KEY to be set in .env.
//
// Node 22's built-in `fetch` is used here — no extra dependency needed.

class GeocodingError extends Error {}

async function geocodeAddress(addressText) {
  const apiKey = process.env.GEOCODING_API_KEY;
  if (!apiKey) {
    throw new GeocodingError(
      'GEOCODING_API_KEY is not configured on the server — add it to .env (see .env.example) to enable manual-address matching.'
    );
  }

  const url = `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(
    addressText
  )}&key=${apiKey}`;

  let json;
  try {
    const res = await fetch(url);
    json = await res.json();
  } catch (err) {
    throw new GeocodingError('Could not reach the geocoding service. Please try again.');
  }

  if (json.status === 'ZERO_RESULTS') {
    throw new GeocodingError("That address couldn't be found. Try adding more detail (city, sub-city, area).");
  }
  if (json.status !== 'OK' || !json.results || !json.results.length) {
    throw new GeocodingError(`Geocoding failed (${json.status || 'unknown error'}).`);
  }

  const { lat, lng } = json.results[0].geometry.location;
  return { latitude: lat, longitude: lng, formattedAddress: json.results[0].formatted_address };
}

module.exports = { geocodeAddress, GeocodingError };
