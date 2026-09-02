# EBN Backend

A real backend (Express + Postgres + Socket.IO) for the app. Currently
covers these features:

1. **Auth** (`/api/auth`) — sign up / sign in / session restore, backing
   the app's role-based smart router (see below).
2. **Tour requests** (`/api/tour-requests`) — the "request a tour" flow,
   replacing the Flutter app's in-memory `LoopController` with a
   persisted, multi-request, per-customer/per-agent system that stays
   correct even if clients disconnect or the server restarts.
3. **Sell requests** (`/api/sell-requests`) — the "Sell my property"
   pipeline: Visitor submits → Admin screens → Agent/Broker claims and
   inspects → Agent submits report → Admin approves → listed. Merged in
   from a standalone service; see below for the full route table.
4. **Affiliate program** (`/api/affiliates`) — the Affiliater role's
   dashboard: shareable codes, referral links, referrals, commission
   earnings, payouts, performance reports, campaigns, and notifications.
   See below for the full route table.

All of the above share the same Postgres database and the same Express
app/server.

## Auth API

All bodies/responses are JSON.

| Method & path | Who calls it | What it does |
|---|---|---|
| `POST /api/auth/signup` | Anyone | Registers a new account. Body: `{ fullName, email, password, role?, phone?, agencyOrLicense?, interestedInFractionalInvesting?, referralCode? }`. `role` is one of `user` (Visitor), `affiliater`, `agent`, `investor`, `admin` — defaults to `user`. Returns `{ user, token }`. `409` if the email is already registered. |
| `POST /api/auth/signin` | Anyone | Body: `{ email, password }`. Returns `{ user, token }`. `401` on bad credentials. |
| `GET /api/auth/me` | Signed-in user | Requires `Authorization: Bearer <token>`. Returns `{ user }` — lets the client restore a session on app restart without re-prompting for a password. |

`token` is a JWT (`JWT_SECRET`/`JWT_EXPIRES_IN` in `.env`), signed with the
user's id and role. Passwords are hashed with bcrypt — plaintext passwords
are never stored or logged.

## What changed vs. the old `LoopController`

| | Old (`LoopController`, client-only) | New (this backend) |
|---|---|---|
| Concurrent requests | One, app-wide | Unlimited, tracked independently |
| Customer history | None | `GET /api/tour-requests?customerId=...` |
| Countdown | `Timer.periodic` in the Flutter app | Runs on the server; keeps going even if every client disconnects |
| Survives a restart | N/A (all state was in memory) | Yes — in-flight countdowns are re-armed from `expires_at` in Postgres on boot |
| Live updates | Shared `ChangeNotifier` in the same process | Socket.IO push to the customer, admin, and agent involved |

## Requirements

- Node.js 18+
- PostgreSQL 14+ (built and tested against 16)

## Setup

```bash
cd backend
npm install
cp .env.example .env      # uses the configured Neon DATABASE_URL
```

Run the migration:

```bash
npm run migrate
```

Start the server locally:

```bash
npm start        # or: npm run dev  (nodemon, auto-restart on file changes)
```

You should see:

```
[server] listening on http://localhost:4000
```

Check it's alive and talking to Postgres:

```bash
curl http://localhost:4000/health
# {"ok":true,"db":"connected"}
```

### Vercel deployment

This backend can be deployed on Vercel using a single serverless function entrypoint.

1. Add `vercel.json` in the `backend/` folder.
2. Configure the Vercel project to use `backend/api.js` as the function entry.
3. Add these environment variables in Vercel:
   - `DATABASE_URL`
   - `JWT_SECRET`
   - `JWT_EXPIRES_IN`
   - `CHAPA_SECRET_KEY`
   - `CHAPA_PUBLIC_KEY`
   - `CHAPA_WEBHOOK_SECRET`
   - `CHAPA_RETURN_URL`
   - `CHAPA_CALLBACK_URL`
   - `CORS_ORIGIN` (optional)

#### Limitations on Vercel

- WebSocket / Socket.IO is not supported as a persistent live transport.
- Background jobs like `investmentPayoutScheduler.start()` and in-memory expiry timers do not run reliably in serverless production.
- For scheduled payouts or expiry re-arm logic, use Vercel Cron, an external worker, or move this logic to a managed job service.

## REST API — Tour requests

All bodies/responses are JSON. All timestamps are ISO 8601 UTC.

| Method & path | Who calls it | What it does |
|---|---|---|
| `POST /api/tour-requests` | Customer | Submit a new tour request. Body: `{ customerId, customerName, assetId, assetTitle }`. Starts at status `pending_approval`. |
| `GET /api/tour-requests?customerId=...` | Customer | That customer's full history, newest first. |
| `GET /api/tour-requests/queue` | Admin | Everything currently needing admin attention (`pending_approval`, `declined`, `expired`), oldest first. |
| `POST /api/tour-requests/:id/approve` | Admin | Dispatches to an agent and starts the countdown. Body: `{ agentId, agentName }`. Works from `pending_approval`, `declined`, or `expired` (i.e. redispatch after a decline/expiry works the same way). Fails with `409` if the request isn't in one of those states (e.g. already dispatched). |
| `GET /api/tour-requests/agent/:agentId/active` | Agent | Requests currently ringing for this agent (status `dispatched`) — an agent can have more than one at once. |
| `GET /api/tour-requests/agent/:agentId` | Agent | This agent's full history. |
| `POST /api/tour-requests/:id/accept` | Agent | Body: `{ agentId }`. Only succeeds if still `dispatched` **to that agent** — `409` otherwise (already handled, expired, or belongs to someone else). |
| `POST /api/tour-requests/:id/decline` | Agent | Same shape and same guard as accept. Puts it back in the admin queue as `declined`. |
| `GET /api/tour-requests/:id` | anyone | Fetch a single request. |
| `GET /health` | — | `{ ok, db }` — confirms the server is up and can reach Postgres. |

### Status lifecycle

```
pending_approval → dispatched → accepted
                       ↓  ↑ (redispatch)
                   declined / expired
```

`expired` happens automatically, server-side, `dispatch_window_seconds` (default 30s,
set via `DISPATCH_WINDOW_SECONDS` in `.env`) after dispatch — no client action needed.

## REST API — Sell requests

All bodies/responses are JSON. Base path: `/api/sell-requests`. This
pipeline is REST-only (no Socket.IO push yet — see notes below).

### Visitor

| Method & path | What it does |
|---|---|
| `POST /api/sell-requests` | Submit a new request. Body requires `ownerUserId, ownerName, ownerPhone, category, title, description, askingPrice, city, addressLine`, plus optional `feeAmount` (default `100`), `feePaid` (default `true`), and **one** of `houseDetails` / `vehicleDetails` / `machineryDetails`. Starts at `pending_admin_approval`. |
| `GET /api/sell-requests?ownerUserId=...` | That owner's full submission history, newest first. |

### Admin — submission screening

| Method & path | What it does |
|---|---|
| `GET /api/sell-requests/pending-submissions` | Everything awaiting a first look, oldest first. |
| `POST /api/sell-requests/:id/approve-submission` | → `open_to_brokers`. `409` if it isn't `pending_admin_approval`. |
| `POST /api/sell-requests/:id/reject-submission` | Body: `{ reason? }`. → `submission_rejected`. Same `409` guard. |

### Agent/Broker — claim

| Method & path | What it does |
|---|---|
| `GET /api/sell-requests/open` | Everything currently `open_to_brokers`, oldest first. |
| `POST /api/sell-requests/:id/claim` | Body: `{ agentId, agentName }`. First-come-first-served — `409` if someone already claimed it (or it's not open). |
| `GET /api/sell-requests/agent/:agentId/claimed` | This agent's `claimed` + `report_rejected` requests. |
| `GET /api/sell-requests/agent/:agentId/pending-reports` | This agent's requests awaiting Admin's report review. |
| `GET /api/sell-requests/agent/:agentId/listed` | This agent's requests that are now live listings. |

### Agent/Broker — inspection report

| Method & path | What it does |
|---|---|
| `POST /api/sell-requests/:id/report` | Body: `{ agentId, media: [{ id, isVideo }], notes }`. Only succeeds if `claimed` or `report_rejected` **and** belongs to this `agentId` — `409` otherwise. → `report_pending_approval`. |

### Admin — report screening → publish

| Method & path | What it does |
|---|---|
| `GET /api/sell-requests/pending-reports` | Everything awaiting final sign-off, oldest first. |
| `POST /api/sell-requests/:id/approve-report` | Body: `{ listedAssetId? }`. → `listed`. `409` if not `report_pending_approval`. |
| `POST /api/sell-requests/:id/reject-report` | Body: `{ reason? }`. → `report_rejected` (agent can revise and resubmit). Same `409` guard. |
| `GET /api/sell-requests/:id` | Fetch a single request (anyone). |

### Status lifecycle

```
pending_admin_approval → open_to_brokers → claimed → report_pending_approval → listed
        ↓                                       ↑  (revise & resubmit)
  submission_rejected                     report_rejected
```

## REST API — Affiliates

All bodies/responses are JSON. Base path: `/api/affiliates`. Every route
below requires `Authorization: Bearer <token>` (`401` without one). Routes
under `/me/...` also require the `affiliater` role (`admin` is allowed too,
for support/debugging); admin-management routes require the `admin` role.
`403` if the role doesn't match.

### Affiliater — code & links

| Method & path | What it does |
|---|---|
| `GET /api/affiliates/me/code` | Returns the caller's shareable affiliate code (e.g. `EBN-6SX766`), minting one on first call. |
| `POST /api/affiliates/me/links` | "Generate Link". Body: `{ assetId? }`. Logs a click (for Reports) and returns `{ code, url }`. |

### Affiliater — referrals

| Method & path | What it does |
|---|---|
| `GET /api/affiliates/me/referrals?status=pending\|completed` | The caller's referrals, newest first. `status` is optional. |

### Affiliater — earnings & payouts

| Method & path | What it does |
|---|---|
| `GET /api/affiliates/me/earnings` | `{ totalEarned, pending, paidOut, processing, availableForPayout }` — all in the affiliate's currency (ETB). |
| `POST /api/affiliates/me/payouts` | Requests a payout. Body: `{ amount? }` — omit to request everything available. `400` if `amount` exceeds what's available (funds already `processing` or `paid` are excluded, so the same commission can't be requested twice). |
| `GET /api/affiliates/me/payouts` | The caller's payout history, newest first. |

### Affiliater — reports

| Method & path | What it does |
|---|---|
| `GET /api/affiliates/me/reports` | `{ totalClicks, totalReferrals, totalCommission, conversionRate, monthly: [{ month, clicks, referrals, commission }] }`. |

### Affiliater — campaigns

| Method & path | What it does |
|---|---|
| `GET /api/affiliates/campaigns` | All campaigns (active first, then upcoming, then ended). |

### Affiliater — notifications

| Method & path | What it does |
|---|---|
| `GET /api/affiliates/me/notifications` | The caller's notification feed, newest first. |
| `POST /api/affiliates/me/notifications/:id/read` | Marks one notification read. |
| `POST /api/affiliates/me/notifications/read-all` | Marks every unread notification read. Returns `{ markedRead }`. |

### Admin — managing referrals & payouts

There's no automated sale-attribution pipeline yet (no checkout flow tags a
sale with the affiliate code that referred it), so referrals are recorded
manually by an admin for now, same as the other admin-approval flows above.

| Method & path | What it does |
|---|---|
| `POST /api/affiliates/:affiliateId/referrals` | Body: `{ customerName, customerUserId?, assetId?, assetTitle, commissionAmount, commissionCurrency? }`. Creates a `pending` referral and notifies the affiliate. |
| `POST /api/affiliates/referrals/:id/complete` | Clears a referral's commission (moves it out of `pending`). `409` if it isn't pending. Notifies the affiliate. |
| `POST /api/affiliates/payouts/:id/mark-paid` | Marks a `processing` payout as `paid`. `409` if it isn't processing. Notifies the affiliate. |

### Admin — managing campaigns

| Method & path | What it does |
|---|---|
| `POST /api/affiliates/campaigns` | Body: `{ title, description, badge, icon?, status?, startsAt?, endsAt? }`. |
| `PATCH /api/affiliates/campaigns/:id` | Body: any subset of the fields above. `404` if not found. |

## REST API — Chat

Backs `broker_chat_screen.dart`, which today only fakes a conversation
with canned/random replies. One thread per (customer, agent, asset) —
chat is always entered from a specific listing.

All routes require auth (`Authorization: Bearer <token>`).

- `POST /api/chat/threads` — customer only. Body: `{ assetId }`. The
  agent is derived server-side from that asset's `broker_id`, not taken
  from the client, and must resolve to a real `users` row with
  `role = 'agent'` — older/seeded listings whose `broker_id` is still a
  legacy mock id (`b1`..`b9`) will 422 until that listing is reassigned
  to a real agent account. Returns the thread (creating it if needed).
- `GET /api/chat/threads` — inbox for the logged-in user (works for
  both customer and agent), newest activity first, with the other
  party's name, the asset's title/image, and an unread count.
- `GET /api/chat/threads/:id/messages?before=<ISO timestamp>&limit=100`
  — paginate backwards from `before` (or from "now" if omitted).
- `POST /api/chat/threads/:id/messages` — body: `{ body }`. Persists the
  message, updates the thread's last-message summary, and pushes a
  `chat_message` socket event to the recipient (see below).
- `POST /api/chat/threads/:id/read` — marks everything as read for
  whichever side of the thread the caller is on.

The Flutter client doesn't use a socket client anywhere yet (see the
polling pattern in `loop_controller.dart`); the socket event is there for
whenever that's worth adding, but polling `GET .../messages` on an
interval works fine in the meantime.

## Live updates (Socket.IO)

Connect to the same host/port as the REST API. After connecting, join the
room(s) relevant to that client:

```js
const socket = io('http://localhost:4000');

// Customer app:
socket.emit('join', { role: 'customer', id: customerId });

// Admin app:
socket.emit('join', { role: 'admin' });

// Agent app:
socket.emit('join', { role: 'agent', id: agentId });
```

Events pushed to the relevant room(s):

- `tour_request:created` — a new request was submitted (→ admin, and that customer).
- `tour_request:updated` — status changed for any reason: dispatch, accept,
  decline, or server-side expiry (→ admin, that customer, and that agent if
  one is assigned).

Every event's payload is the full, current tour_request row — same shape as
the REST responses above, so the client can just replace its local copy of
that request.

## Notes on the design

- **One countdown timer per dispatched request**, tracked in memory
  (`src/scheduler.js`) and re-armed from Postgres's `expires_at` on server
  boot — so a restart never loses a countdown, and a request that was
  already overdue while the server was down expires immediately instead of
  hanging forever.
- **Row-level guards, not just app-level checks**: every mutating endpoint's
  `UPDATE` includes the expected current status (and, for accept/decline,
  the expected `agent_id`) directly in the `WHERE` clause. Two near-simultaneous
  requests (e.g. accept + the countdown firing at the same instant) can't
  both "win" — whichever one the database applies first makes the second a
  no-op, which the route reports as `409` rather than silently corrupting
  state.
- No auth is enforced here — `customerId`/`agentId` are trusted from the
  request body, matching the app's current `MockAuthService`. When you're
  ready to wire up real accounts, that's the seam: verify a session/JWT and
  derive these IDs from it server-side instead of trusting the body.

**Sell requests specifically:**

- **No file storage** — `report_media` only stores `{ id, isVideo }` pairs
  from the client's mock media picker. If/when a real camera/file picker is
  wired up, point uploads at real object storage (S3, GCS, etc.) and store
  the resulting URLs in this same JSONB array — no schema change needed.
- **Category-specific wizard answers** (`house_details` / `vehicle_details`
  / `machinery_details`) are stored as-is in JSONB rather than normalized
  into columns, so new wizard fields never need a migration.
- **Doesn't own listings/assets** — approving a report just marks the
  request `listed` and stores whatever `listedAssetId` is passed in (or
  `null`). Creating the actual public listing/asset record is a separate
  concern; wire that up wherever the asset catalog lives.
- **No real-time push yet** — this pipeline is REST-only, unlike tour
  requests. If you want Socket.IO events here too (e.g. `sell_request:created` /
  `sell_request:updated`), the same broadcast-after-each-mutation pattern
  used in `routes/tourRequests.js` drops in cleanly.
- Same "no auth enforced" caveat as tour requests — `ownerUserId`/`agentId`
  are trusted from the request body for now.

## Next steps: wiring this into the Flutter app

**Tour requests** — this backend is a drop-in replacement for
`LoopController`'s responsibilities. On the Flutter side that means:

1. Add `http` and `socket_io_client` packages.
2. Replace direct calls to `loop.customerRequest(asset)` /
   `loop.adminApprove()` / `loop.agentAccept()` / `loop.agentDecline()` with
   calls to this API.
3. Replace `ChangeNotifier.notifyListeners()` triggered by local state
   changes with a listener on the relevant Socket.IO events, updating a
   `ChangeNotifier` that now holds a `List<TourRequest>` instead of a single
   stage/asset pair (mirroring how `SellRequestController` already holds a
   list).

**Sell requests** — `lib/providers/sell_request_controller.dart` already
holds a `List<SellRequest>`, so the shape matches; the remaining work is
pointing it at real HTTP calls (`POST /api/sell-requests`, `.../claim`,
`.../report`, `.../approve-submission`, etc.) instead of whatever mock/local
data it currently uses, the same way `auth_service.dart` was pointed at
`/api/auth`.

Happy to build that Flutter-side controller and wire up the three screens
next if you want to keep going.
