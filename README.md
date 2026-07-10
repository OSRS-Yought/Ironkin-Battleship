# Battleship Bingo — clan event tracker

A static site that tracks a single board: **the enemy's**. Clanmates sign in with
Discord, pin their avatar to the tiles they're working, and mark each tile **HIT**
or **SPLASH** when it's completed. Everything is live — no refreshing.

Hosted on GitHub Pages. Data lives in Supabase (free tier).

---

## Why there's a database at all

GitHub Pages serves files. It cannot store anything. Any tracker where two people
see the same state needs a backend somewhere. Supabase gives you Postgres, realtime
websockets, and Discord OAuth as a native provider, and the browser talks to it
directly — so the site itself stays a static folder you can drop into any repo.

Nothing secret lives in the database. There are no ship placements to hide. The
`anon` key in `config.js` is designed to be public; row-level security in
`schema.sql` is what actually controls who can write what.

---

## Setup

### 1. Supabase project

1. Create a project at supabase.com. Any region near you (`us-west-1`) is fine.
2. **SQL Editor** → paste all of `schema.sql` → Run.
3. **Project Settings → API** → copy the **Project URL** and the **anon public** key.

### 2. Discord OAuth

1. Go to <https://discord.com/developers/applications> → **New Application**.
2. **OAuth2** → copy the **Client ID** and **Client Secret**.
3. Still in Discord, add a redirect URL. Supabase shows you the exact one under
   **Authentication → Providers → Discord**; it looks like
   `https://YOUR-PROJECT-REF.supabase.co/auth/v1/callback`.
4. In Supabase: **Authentication → Providers → Discord** → enable it, paste the
   client ID and secret, save.
5. In Supabase: **Authentication → URL Configuration** → set **Site URL** to your
   GitHub Pages URL (`https://yourname.github.io/clanboard/`) and add the same URL
   under **Redirect URLs**. Add `http://localhost:8000` too if you want to test locally.

### 3. Fill in `config.js`

```js
window.BB_CONFIG = {
  supabaseUrl: "https://abcdefgh.supabase.co",
  supabaseAnonKey: "eyJhbGciOi...",
  title: "Battleship Bingo",
  subtitle: "Enemy waters",
};
```

### 4. Deploy

Push `index.html`, `config.js`, and `tiles.seed.json` to a repo, then
**Settings → Pages → Deploy from branch → main / (root)**.

To test locally first: `python3 -m http.server 8000` in this folder.

### 5. Make yourself an admin

Sign in once. Then in the Supabase SQL Editor:

```sql
update members set is_admin = true where username = 'your_discord_username';
```

Refresh. A **Setup** tab appears.

---

## Running the event

**Build the board.** Setup → upload the board screenshot, set columns and rows
(10 × 10 for the board you sent), hit *Slice & publish*. The image is cut into one
tile per cell client-side, so each tile carries its own art. If `tiles.seed.json`
has exactly `cols × rows` entries, the names and ×N quantities load with it.

I transcribed all 100 tiles off your screenshot into `tiles.seed.json` — check it
before the event, a few were small in the source. `"Broken Dragon Hook"` in
particular is worth a second look.

**Shuffle.** After both teams place ships, Setup → *Shuffle the board*. This
randomizes which task sits in which cell. Claims, hits, and splashes follow the
task, not the cell, so it is safe to shuffle mid-event if you need to.

**During the event.** Anyone signed in can:

- click a tile → **I'm on it** to pin their Discord avatar to it
- add *anyone else* to a tile (deliberate — you can slot a teammate who's mid-raid)
- mark a completed tile **Hit** or **Splash**
- leave notes on a tile
- **Undo** back to unfired if someone misclicks

Up to three avatars show on a tile; more collapse to `+n`. The **Crew** tab lists
every member and exactly which tiles they're sitting on, which is the "who is doing
what" view at a glance.

**Reset shots** clears every hit, splash, and claim but keeps the tiles and art —
for a second round on the same board.

---

## Permissions, honestly

| Action | Who |
|---|---|
| See the board | Anyone who signs in with Discord |
| Claim / unclaim any tile | Any signed-in member |
| Mark hit / splash / undo | Any signed-in member |
| Edit notes | Any signed-in member |
| Build, shuffle, reset | Admins only |

Anyone with the link can sign in with any Discord account. There's no clan check.
That's usually fine for an internal event — you're posting the link in your own
Discord, and any griefing is both reversible and attributable, since every hit
records who called it.

If you want it tighter, two options:

1. **Allowlist.** Insert your clan's Discord user IDs into `members` ahead of time
   and change the `members_insert` policy to require the row already exist.
2. **Guild check.** Request the `guilds` scope at sign-in and verify guild membership
   against `session.provider_token` before rendering. Note that Supabase does not
   persist the provider token past the initial redirect, so this check only runs at
   login, not on refresh.

---

## Cost

Supabase free tier: 500 MB database, 5 GB egress, 200 concurrent realtime connections.
A 100-tile board with sliced art is roughly 400 KB total. You will not come close.

Free projects pause after a week of no activity. Any request wakes them, but the
first load after a pause is slow. Open the site once before the event starts.
