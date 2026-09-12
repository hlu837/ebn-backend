// Turns a manually typed address into coordinates so it can be used the
// same way GPS coordinates are — for nearby-agent matching. Uses Google's
// Geocoding API when available, with automatic fallback to OpenStreetMap Nominatim.

class GeocodingError extends Error {}

async function geocodeWithNominatim(addressText) {
  const url = `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(
    addressText
  )}`;
  const res = await fetch(url, {
    headers: { 'User-Agent': 'OnsiteApp/1.0 (Node.js)' },
  });
  if (!res.ok) return null;
  const data = await res.json();
  if (Array.isArray(data) && data.length > 0) {
    const first = data[0];
    const lat = parseFloat(first.lat);
    const lng = parseFloat(first.lon);
    if (Number.isFinite(lat) && Number.isFinite(lng)) {
      return {
        latitude: lat,
        longitude: lng,
        formattedAddress: first.display_name,
      };
    }
  }
  return null;
}

async function geocodeAddress(addressText) {
  const apiKey = process.env.GEOCODING_API_KEY;

  if (apiKey) {
    try {
      const url = `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(
        addressText
      )}&key=${apiKey}`;
      const res = await fetch(url);
      const json = await res.json();

      if (json.status === 'OK' && json.results && json.results.length) {
        const { lat, lng } = json.results[0].geometry.location;
        return { latitude: lat, longitude: lng, formattedAddress: json.results[0].formatted_address };
      }
      if (json.status === 'ZERO_RESULTS') {
        const fallback = await geocodeWithNominatim(addressText).catch(() => null);
        if (fallback) return fallback;
        throw new GeocodingError("That address couldn't be found. Try adding more detail (city, sub-city, area).");
      }
    } catch (err) {
      if (err instanceof GeocodingError) throw err;
      // Google API error or REQUEST_DENIED — fall through to Nominatim
    }
  }

  // Fallback to OpenStreetMap Nominatim (free, no API key required)
  try {
    const fallback = await geocodeWithNominatim(addressText);
    if (fallback) return fallback;
  } catch (err) {
    // Ignore fetch errors to throw friendly error below
  }

  throw new GeocodingError("Address lookup was unsuccessful. Try adding more detail (e.g. Bole, Addis Ababa) or sharing GPS location.");
}

module.exports = { geocodeAddress, GeocodingError };

