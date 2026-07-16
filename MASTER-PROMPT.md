# MASTER PROMPT — feed this to Claude as `/goal`

Copy everything below the line into Claude Code.

---

/goal Build **INFECTED** — a production-ready, fully playable, public 30-player Roblox round game — end to end, in the existing repo at `~/roblox-infected` (public GitHub: `oh-ashen-one/roblox-infected`). Work autonomously through every phase below; only stop for things that literally require me (Roblox sign-in, publish confirmation, Robux-priced product creation approvals). The bar is production: assume 1,000+ concurrent players across many 30-player servers on day one. Read `docs/research.md` first — it contains the competitor research this design is based on; follow its conclusions.

**COMPLETION MANDATE — this goal is not done until the game is LIVE.** Do not stop at a plan, a skeleton, a "core loop works," or a single phase. Keep working phase after phase, session after session if needed, until every item in the Definition of Done below is checked. If you finish a phase, immediately start the next one. If something blocks one track (e.g. waiting on me), keep building another track in parallel — never idle. Never declare victory early: "done" means a stranger can find the game on Roblox, join a public 30-player server, and play full rounds without hitting a bug.

## Definition of Done (ALL must be true before you stop)

- [ ] Every round-flow state below works end to end, verified in multi-client playtests (Studio local server with 4+ simulated players), including all edge cases in Phase 6.
- [ ] All three maps built, streamed, and rotating via map vote.
- [ ] Combat fully server-authoritative and playtested: guns, throwing knives, conversion, spawn protection, anti-cheat rejections actually observed working.
- [ ] Full meta shipped: economy payouts, XP/levels, shop, crates with card-flip reveal, skins equipping and persisting via ProfileStore across rejoins (tested).
- [ ] All UI screens exist and work on desktop + mobile touch layout.
- [ ] Gamepasses + dev products created, wired, and test-purchased in Studio sandbox; `ProcessReceipt` idempotency verified.
- [ ] CI green: selene, stylua --check, rojo build, and the test suite all pass on main.
- [ ] Game published PUBLIC on Roblox with 30-player servers, icon, thumbnails, and a keyword-rich description; I confirmed the publish and at least one real public server was joined and a full round played.
- [ ] Post-launch runbook committed (`docs/runbook.md`): what to monitor, how to hotfix, exploit-report triage.

If any box is unchecked, the goal is still in progress — continue.

## The game

**Concept:** COD Infected × Murder Mystery 2. 30 players per server. Each round, ONE player is secretly infected — no visual difference, nobody knows who. The hidden infected hunts with one-hit throwing knives (thrown + melee stab). Every kill converts the victim into a *visible* zombie who joins the infected team with a weaker knife. Survivors carry real guns. Round ends on timer or full infection; then a dramatic reveal screen shows who Patient Zero was, who survived, and MVP stats.

**Round flow (state machine, server-authoritative):**
1. **Intermission (25s):** map voting between 3 maps, loadout selection, shop browsing. Needs ≥4 players to start (scale rewards down under 10).
2. **Round start:** all 30 spawn armed as survivors. Server secretly picks Patient Zero (weighted so recent Patient Zeros are deprioritized). They get a private "YOU ARE INFECTED" role card only they see. **Stealth phase:** infected looks identical to everyone, holds a hidden knife, has +20% sprint and one-hit kills. No one is revealed until first blood.
3. **First blood:** the victim converts — ragdoll + infection VFX, respawns in ~3s as a visible zombie (green skin/particles) near the action but not inside enemy sightlines. Patient Zero stays *visually hidden* even after first blood (their kills reveal that "the infection has begun" via a global alert, but not who) — they are only unmasked if killed or at round end. Converted zombies are always visible.
4. **Snowball:** base timer 5:00, **+20s per conversion** (capped at 8:00 total). Zombies respawn instantly on death (they're already infected — dying as a zombie just respawns them after 3s). Survivors who die to *anything* (including fall damage) convert. As the horde passes 25% / 50% / 75% of the lobby, unlock zombie classes (research doc: Frosted Infection pattern) — e.g. Runner (+speed, less HP), Tank (+HP, slow), Screamer (survivor-position pulse on a long cooldown).
5. **Endgame:** last 3 survivors get a global position ping every 15s (anti-camp, per COD). Last survivor alone gets a "LAST STAND" buff — damage resist + a heavy weapon — spectator cams of all zombies focus them, bounty announced.
6. **Round end:** survivors win if ≥1 survivor lives at timer end; infected win on full conversion. Reveal screen: Patient Zero unmasked with a spotlight, survivors listed, MVP stats (most conversions, most zombie kills, first blood, last survivor). 10s, then back to intermission.

**Combat:**
- Survivor guns: fixed, fair loadouts (no pay-to-win stats) — pick 1 primary (assault rifle / shotgun / SMG) + pistol sidearm. Server-authoritative hitscan: client shows instant visual tracers/effects, server raycasts and validates distance, line-of-sight, fire-rate cooldown, and ammo before applying damage; reject anything that fails. Guns damage zombies (zombies have enough HP that it takes commitment: ~2–4 shots) and do nothing to unrevealed survivors (no team-kill griefing) — but shooting a *hidden* Patient Zero works and unmasks them if it kills them (survivors win the mind game like MM2's sheriff).
- Infected knives: throwing knife with a real projectile arc simulated server-side (client-predicted visuals), one-hit conversion on survivors; melee stab in close range. Converted zombies get melee-only claws/knife, 2-hit kill, so Patient Zero stays the apex threat.
- Anti-exploit: ALL role assignment, conversion, damage, timers, and reward grants live on the server. RemoteEvents are hostile input — type-check, sanity-check, rate-limit every one. Server-side movement sanity checks (teleport/speed detection) since infected speed is the #1 exploit surface; check whether Roblox's server-authoritative movement beta can be enabled and use it if so.

**Maps (build 3 at launch, fully in code / Rojo-managed or as .rbxm assets committed to the repo):**
- Sized for 30 players, COD-style: defensible-but-breachable holdout spots (rooftops, back rooms with two entrances), multiple approach angles everywhere, throwing-knife arcs over cover. No spot with a single choke.
- Themes: (1) abandoned mall, (2) suburban street at night, (3) research facility. Lighting/atmosphere does heavy lifting; keep instance counts mobile-friendly (<20k in loaded radius).
- Maps live in ServerStorage, cloned into Workspace per round, destroyed after — StreamingEnabled on, StreamingMinRadius ~256 / TargetRadius ~512.
- Spawns: survivors scattered in groups of 2–3; spawn protection = 3s forcefield; zombie respawns near action but never in survivor sightlines.

**Progression & economy (research doc §2 patterns):**
- Coins: +8 per zombie kill (survivor), +25 per conversion (infected), +40 first blood, +75 survive full round, +100 last survivor, win bonus 2x. XP mirrors coins; levels gate cosmetic unlocks.
- Cosmetic-only monetization: knife & gun **skin rarity ladder** (Common→Legendary→Chroma-style animated), crates with card-flip reveal (show what you *could* have gotten), coins or Robux keys. This is the MM2-proven revenue engine.
- Gamepasses: 2x Coins, XP Boost, VIP (emotes + name color + extra loadout slot), Radio. Dev products: coin packs, crate keys, "Patient Zero token" (guarantees first-infected next round, one per round max). Single centralized idempotent `ProcessReceipt` (record receipt IDs). Create the products via Studio/web when publishing and wire IDs into a config module.
- Persistence: **ProfileStore** (not ProfileService — unsupported) with session locking. Store coins, XP/level, owned skins, equipped loadout, lifetime stats, daily streak.

**UX/UI:** private role card at round start, kill feed, horde counter + timer HUD, conversion alerts, map vote UI, shop + crate-opening UI, end-of-round reveal screen, settings (the usual: FOV, gore toggle, music/SFX volume). Mobile + console friendly: touch buttons for throw/shoot/sprint, gamepad bindings. Sounds/music via Roblox audio library assets.

## Engineering standard (non-negotiable)

- Fully scripted Luau in `src/` synced via **Rojo 7** (`default.project.json` already scaffolded). Toolchain pinned in `rokit.toml` — add **Wally** (packages: ProfileStore, a signal lib, a Zone/utility lib as needed), **Selene** lint, **StyLua** format. Add a GitHub Actions CI that runs selene + stylua --check + `rojo build`.
- Architecture: `src/server` (RoundService state machine, RoleService, CombatService, ConversionService, EconomyService, DataService/ProfileStore, AntiCheatService, MonetizationService), `src/client` (input controllers, viewmodel/weapon FX, all UI), `src/shared` (GameConfig — every tunable number in ONE config module — remote definitions with typed validation, types).
- Tests where they pay off: round state machine transitions, reward math, remote validators (TestEZ or Jest-Lua, run in CI).
- Server settings on publish: **Max Players 30**, reserve 1–2 social slots for friends-joining, join queue on.
- Commit in coherent increments with real messages; push to `main` regularly. Update README as the game takes shape.

## Phases (work through all of them)

1. **Foundation:** Wally/Selene/StyLua/CI setup, GameConfig, remote layer with validation, round state machine skeleton with tests.
2. **Core loop:** role assignment, conversion, timers, win conditions — playable with placeholder map and placeholder combat. Verify in Studio multi-client test (Rojo build + Studio's Start Local Server with multiple players).
3. **Combat:** server-auth hitscan guns + projectile knives, damage/HP model, ragdolls, spawn protection, anti-cheat checks.
4. **Maps:** all three maps, spawn systems, streaming, per-round clone lifecycle.
5. **Meta:** economy, ProfileStore data, shop, crates, skins, gamepasses/dev products, UI polish, sounds, mobile/console input.
6. **Hardening:** multi-client playtests of every win/edge case (Patient Zero leaves mid-round → reassign or end round; server shutdown mid-round → BindToClose saves; sub-4-player lobbies), rate-limit audit, memory profile.
7. **Ship:** publish public to Roblox (I'll be signed in — pause for my confirm on the actual publish + product price approvals), fill out the game page (icon, thumbnails, description with genre keywords), then a post-launch checklist doc (what to monitor: server crashes, exploit reports, D1 retention levers).

Throughout: playtest via Studio's multi-player local server after each phase — don't declare a phase done until you've actually watched the behavior work. When something needs my Roblox session (plugin install, sign-in, publish), tell me exactly what to click and wait — but keep building everything else while you wait. Do not end until the entire Definition of Done at the top is satisfied: a complete, tested, live, publicly playable production game.
