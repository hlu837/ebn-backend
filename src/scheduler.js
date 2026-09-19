// Real server-side countdown for each dispatched request — this is what the
// old client-only `Timer.periodic` in LoopController couldn't do safely:
// the expiry now happens even if every client disconnects, and survives a
// server restart by re-reading `expires_at` from Postgres on boot.

const timers = new Map(); // id -> Timeout

function schedule(id, expiresAt, onExpire) {
  cancel(id);
  const msLeft = new Date(expiresAt).getTime() - Date.now();
  const timeout = setTimeout(() => {
    timers.delete(id);
    onExpire(id);
  }, Math.max(msLeft, 0));
  timers.set(id, timeout);
}

function cancel(id) {
  const existing = timers.get(id);
  if (existing) {
    clearTimeout(existing);
    timers.delete(id);
  }
}

module.exports = { schedule, cancel };
