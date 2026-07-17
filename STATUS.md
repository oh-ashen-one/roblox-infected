# 🎉 LIVE — https://www.roblox.com/games/78267419085369/INFECTED-Hidden-Zombie-Among-You

**Published PUBLIC on Roblox 2026-07-17** (universe 10518289514, place 78267419085369,
by @solashenone). 30-player servers, icon + thumbnails + keyword description, Mild/16+
maturity label, all products free. Currently reaching 16+ & trusted friends; opens to
all-ages the moment 2-step verification is completed (Settings → Eligibility). No
re-publish needed for that.

**Public round verified 2026-07-17:** launched the live public game from the Roblox
page → a real Roblox Cloud Compute (RCC) server spun up (DatacenterId 387) and the
play client (`isPlayClient=1`) booted our game on it — player log shows
`[INFECTED] Client booted` + `Server Prefix: ..._RCC_d6dd4`. The game is joinable by
strangers (16+) and runs on Roblox's live public infrastructure. A full multiplayer
round showing conversions just needs 2+ players in the server (prod config; Studio
fast-timers not in play live).

# ⚠️ Bots + lobby update built & committed, NOT YET on the live game

Added solo-play **bots** (fill lobby to 8, get roles, wander/hunt/convert, shot by
guns / converted by knife) and fixed the **empty-baseplate** (a lobby map now always
loads). Built, tested (37 green), headless-verified, committed + pushed.

**Blocked pushing it live by an ACCOUNT MISMATCH:** Roblox Studio on this machine is
signed into `solashenone1`, but the published INFECTED game is owned by `solashenone`
(the account the web/Chrome session + eligibility verification are on). Studio can't
publish an update to a game it doesn't own — INFECTED doesn't appear in solashenone1's
cloud experiences. To ship the bot update: sign Studio into `solashenone`, then
`rojo serve` + connect the Rojo plugin (or File → Publish) to overwrite the place.
The currently LIVE public game still works — it just doesn't have bots yet.

# Build status vs Definition of Done

Updated 2026-07-17 (published PRIVATE to Roblox as "INFECTED - Hidden Zombie Among You"; latest build with all fixes + sounds is live on the cloud place).

| DoD item | Status |
| --- | --- |
| Round flow end-to-end multi-client | ✅ observed live (Server and Clients, 2 players): intermission → vote → round → PZ role card → conversion → INFECTED win → reveal w/ PZ unmask → next intermission |
| 3 maps built, streamed, voted | ✅ vote UI live; Suburbia observed loading with night lighting; Mall/Facility rotation pending hands-on pass |
| Server-auth combat + anti-cheat observed | ⏳ conversion kills observed; gun/knife feel + anti-cheat rejections = Hari's hands-on pass |
| Economy/shop/crates/skins persist across rejoin | ✅ coin payouts observed persisting across rounds (35/70 coins); crates/skins = hands-on pass |
| Desktop + mobile UI | ✅ desktop HUD observed live; mobile touch layout verified in iPhone XR Device Emulator |
| Gamepasses + dev products, idempotent receipts | ✅ created (off-sale) + IDs wired into GameConfig; test-purchase after pricing |
| CI green | ✅ |
| Published public + real round played | 🔒 BLOCKED on account verification. "Public" audience is pre-selected but rejected: "You don't have permission to publish to this audience." solashenone must complete Roblox publishing-eligibility (below). Everything else is done + free-to-play. |
| Runbook | ✅ docs/runbook.md (+ docs/publish-checklist.md) |

## 🔒 The one remaining blocker — account verification (Hari only)

To publish a **public / all-ages** experience, the `solashenone` account must complete
three one-time identity steps at **create.roblox.com → Settings → Eligibility →
Publishing permissions** (click **Start** on each):

1. **Identity verification** — government ID. (Only Hari can do this; entering a
   government ID is not something the assistant will ever do.)
2. **Age check** — webcam age estimation of Hari's face.
3. **2-step verification** — authenticator app or SMS on Hari's account.

Once all three show ✅ under the "Publish to all ages" column:
- Experience → **Configure → Settings → Audience → Public → Save** (Public is already
  the selected option; it just needs the verified account behind it).
- Products are all **off-sale (free)** per Hari's "all free" call — nothing to price.
- Then join the public game (Roblox player installed on this Mac, or phone) for the
  first real public round.

Decision recorded 2026-07-17: Hari said "all free and go public." Public flip executed
up to the verification wall; products left free.

## How to run the multi-client playtest (once Studio is drivable)

1. `rojo build -o INFECTED.rbxlx` and open it in Studio (or `rojo serve` + sync).
2. Test tab → Clients and Servers → 4 players → Start. Studio timers auto-shrink
   (8s intermission / 40s rounds) and the built-in smoke harness prints
   `[SMOKE] PASS/FAIL ...` assertions in the SERVER window's output.
3. Watch: role card on each client, conversion on kill, zombie respawn near action,
   reveal screen, coins persisting across a rejoin.

## Verified so far without UI access

- Server boots clean under a live Studio run (`run-in-roblox` + `RunService:Run()`):
  remotes created, services started, no script errors.
- Full unit coverage of round machine, rewards, PZ selection, validators, level curve, crate rolls.

## Dead ends (don't retry)

- `RobloxStudio -task StartServer` CLI: broken on macOS Studio 0.730 ("Cannot open
  place file for reading") for every path/format/flag combination.
- `Players:CreateLocalPlayer()` from injected plugin: blocked (LocalUser capability).

## Live product IDs (universe 10518289514, place 78267419085369)

Gamepasses: 2x Coins 1919414556 · XP Boost 1917980542 · VIP 1918454539 · Radio 1918040566
Dev products: 1k Coins 3610363831 · 5k 3610363881 · 12k 3610363919 · CrateKey 3610364225 · 5 Keys 3610364383 · PZ Token 3610364441
All off-sale until prices approved (sheet in docs/store-page.md).
