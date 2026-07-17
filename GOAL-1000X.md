# INFECTED — 1000× Upgrade Spec (`/goal` target)

**Mission:** Take the already-live, playable INFECTED (30-player COD-Infected × MM2 round
game) and turn it into a genuinely sticky, viral-feeling Roblox hit. Keep it fully
server-authoritative, keep CI green, and **ship each phase live to the real place**
(universe 10518289514, place 78267419085369, owner @solashenone) — don't just build in a
branch. This is a keep-going-until-done goal: you are not finished until every phase's
Definition of Done is met, verified in a Studio playtest, and published.

## Ground rules (do not violate)
- **Server-authoritative always.** All damage, conversions, currency, unlocks, and drops
  are decided on the server (`CombatService`, `EconomyService`, `RoundService`). Clients
  only send intent + play cosmetics. Never trust a client number.
- **No pay-to-win in combat.** Monetization is cosmetics, convenience, boosts to
  coins/XP, and servers — never raw combat advantage. Keep `ProcessReceipt` idempotent.
- **Server-driven content.** Adding a skin, crate, map-event, quest, or seasonal item
  must NOT require an app/place republish where avoidable — drive it from config/data
  the way Merl TRENDS does (a data row + asset, hot-loadable). Build a `LiveConfigService`
  that reads a versioned config table and fans out to clients.
- **Every phase ends green:** `stylua src && selene src && lune run tests/run && rojo build`
  all pass, plus a Studio solo playtest (bots fill the lobby) and, where it changes live
  behavior, a published update + a quick real-server smoke check.
- **Mobile is first-class.** Every new UI and control ships desktop + touch + gamepad.
- **Bots keep the game alive.** Low-population public servers must silently backfill with
  bots so a solo player always gets a full-feeling 8+ match. Never show empty maps.

## Phase A — Game feel / juice (the thing that makes clips)
Make every hit, kill, and conversion feel violent and satisfying.
- Hit markers + damage numbers, crosshair bloom, muzzle flash, shell ejection, tracer
  polish, weapon recoil kick + FOV punch, sprint FOV widen, landing/step sounds.
- Knife: spinning trail, thunk impact, slow-mo micro-freeze on a conversion kill.
- Conversions: green infection burst VFX, screen-edge vignette when you turn, a distorted
  "you're infected" stinger, ragdoll-on-death (`Humanoid` ragdoll or physics constraints).
- Screen shake + controller/mobile haptics scaled to event weight.
- A real **kill feed** (top-right) and an on-screen conversion ticker.
- Layered sound design + dynamic music (calm → tense as survivors dwindle → last-stand
  theme). Respect a mute/volume setting. Use `SoundService` groups.
**DoD:** a 20-second clip of one kill + one conversion looks share-worthy; all effects are
client cosmetic over server-authoritative events; mobile haptics fire.

## Phase B — Bots that feel like players
- Replace wander/chase with `PathfindingService` navigation + line-of-sight, cover use,
  and stuck-recovery. Run AI in parallel Luau `Actor`s if perf needs it.
- Difficulty tiers + per-bot "personality" (aggressive/cautious/roamer), believable
  random display names + basic avatar variety, so a solo lobby reads as real people.
- Bot Patient Zero actually stalks and picks isolated targets; bot survivors flee, group
  up, and shoot back with human-like reaction delay.
- Seamless public backfill: join a live server with 3 humans → bots top it up toward a
  full match and quietly leave as real players arrive.
**DoD:** a solo playtest is fun and legible; bots path around obstacles, don't T-pose or
clump on spawns, and the round always resolves. Extends `BotService`.

## Phase C — Progression, retention & rewards
- **Leveling** with a meaningful unlock track (skins, knives, kill-effects, titles).
- **Daily login streak** + **daily/weekly quests** ("convert 5", "survive 3 rounds",
  "win as PZ") granting coins/XP/keys.
- **Season pass / battle track** (free + premium lanes) driven by `LiveConfigService`.
- **Crates & rarity** upgrade: animated crate-open sequence, rarity odds shown
  (respect `PolicyService:ArePaidRandomItemsRestricted`), dupe→shard crafting.
- **Cosmetic depth:** gun skins, knife skins (PZ), zombie skins, kill effects, victory
  emotes/dances, nametag titles, trails. All server-granted, equip persisted in
  `ProfileStore` via `DataService`.
**DoD:** a returning player has a clear "next unlock," dailies reset correctly, and every
grant/equip round-trips through a rejoin. New cosmetics addable via config, no republish.

## Phase D — Content breadth & round variety
- Grow to **5–8 maps** with distinct layouts, plus per-map lighting/weather/time-of-day.
- **Special infected abilities** unlocked by conversions or map events (e.g. lunge,
  smoke/screamer, brief invisibility) — balanced, server-validated, telegraphed.
- **Round modifiers / events** ("Blackout", "Double coins", "Juggernaut PZ") chosen at
  vote time from a server-driven event table.
- Map-specific interactables: doors, generators, alarms, loot spawns.
**DoD:** map + modifier voting works; each map streams cleanly (`StreamingEnabled`) on
mobile; abilities are server-authoritative and can't be spoofed.

## Phase E — Social & virality
- **Parties / friend invites**, join-friend, and reserved party slots.
- **Leaderboards** (global + friends): wins, conversions, survival streak — via
  `OrderedDataStore`, anti-tamper.
- **End-of-round share screen:** MVP, PZ reveal, your stats, "closest survivor" — visually
  designed to be screenshotted/clipped, with a replay-worthy PZ unmask.
- **Referral / group rewards** and a "play again with this lobby" flow.
- Spectator/kill-cam after death instead of a dead wait.
**DoD:** leaderboards persist and resist tampering; invite flow works; the share screen is
clip-ready; a dead player is engaged (spectate) not idle.

## Phase F — Onboarding / FTUE
- First-launch flow: role explainer, control coach (desktop/touch/gamepad), and a gentle
  first match (vs bots, slightly favorable) so new players get an early win + first unlock.
- Contextual tips the first time you're PZ, first conversion, first gun pickup.
**DoD:** a brand-new account understands the game within one match and leaves with a reward.

## Phase G — Live-ops, analytics & hardening
- `LiveConfigService`: versioned, hot-loadable config for skins/crates/events/quests/season
  (validate + safe-fallback; never brick a live server on a bad config).
- **Analytics:** structured events (round start/end, conversions, purchases, funnel steps,
  retention) to a sink you can read; a lightweight dashboard/doc.
- **Anti-cheat expansion:** rate-limit every remote (token bucket already exists), sanity
  bounds on positions/fire cadence, teleport/speed checks, telemetry on rejections, soft
  kick/ban ladder.
- **Perf pass:** instance pooling for VFX, streaming tuning, AI throttling, memory checks
  on a full 30-player + bots server.
**DoD:** you can add a cosmetic/event by editing config only; cheating attempts are logged
and blunted; a full server holds framerate on mid-tier mobile.

## Phase H — UI/UX overhaul & polish
- Themed, animated main menu, loadout/locker, shop, season, quests, settings — cohesive
  art direction, readable on phone. Accessibility (colorblind-safe infection cues, text
  scale, control remap, SFX/music sliders).
- Consistent HUD: ammo, timer, survivor count, radar/last-stand, objective banners.
**DoD:** the whole app looks like a shipped commercial Roblox title, desktop + mobile.

## Execution order & loop
Work A→H, but ship in thin vertical slices: each slice = build → green CI → Studio
playtest (bots) → publish live → note it in `STATUS.md` + `docs/runbook.md`. Prioritize
**Phase A (juice) and Phase B (bots)** first — they most change how the game *feels* in a
YouTube clip. Then C (retention) for stickiness. Keep the git history clean, commit per
slice, push to `github.com/oh-ashen-one/roblox-infected`, and keep `STATUS.md` honest about
what's live vs built. Do not stop until every DoD above is met and published.

## Toolchain note (this machine)
rokit binaries can get SIGKILLed by macOS after reinstall — re-sign with
`codesign --force --sign - <binary>` (both `~/.rokit/bin/*` and the versioned
`~/.rokit/tool-storage/**` binaries) if `stylua/selene/rojo/lune` exit 137.
