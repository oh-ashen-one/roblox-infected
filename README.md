# INFECTED 🧟

> A 30-player hidden-infection round game for Roblox — **COD: Infected** meets **Murder Mystery**. One player is secretly Patient Zero. Nobody knows who. Trust no one.

**▶️ Play it live:** [roblox.com/games/78267419085369](https://www.roblox.com/games/78267419085369)

![Luau](https://img.shields.io/badge/Luau-strict-blue)
![Rojo](https://img.shields.io/badge/Rojo-managed-orange)
![tests](https://img.shields.io/badge/tests-84%20passing-brightgreen)
![status](https://img.shields.io/badge/status-live-success)
![license](https://img.shields.io/badge/license-MIT-lightgrey)

---

## The game

30 players drop into a lobby and vote on a map. When the round starts, **one player is secretly infected** — they look and spawn exactly like everyone else.

- 🔪 **Patient Zero** blends in with the survivors and hunts with a **one-hit throwing knife**. Every kill turns the victim into a visible zombie on the infected team.
- 🔫 **Survivors** carry real, server-authoritative guns and have to figure out who to trust as the horde quietly grows.
- 🧟 **Zombies** join the hunt with melee and special class abilities. Last survivor standing wins it for the humans.
- 🏆 When the timer ends, a dramatic **reveal board** unmasks Patient Zero and crowns the MVP.

No friends online? The lobby fills with **smart bots** so you always get a full match.

## Features

<table>
<tr><td>

**⚔️ Combat & feel**
- Server-authoritative guns, throwing knives, melee (raycast-validated)
- Trauma camera shake, damage numbers, muzzle flash, impact spray
- Full-screen infection takeover + physics ragdoll death corpses
- Tension music that ramps with the horde

</td><td>

**🤖 Smart bots**
- PathfindingService navigation with stuck-recovery
- Line-of-sight, difficulty tiers & personalities
- Survivors roam / group / flee / shoot back
- Patient Zero bot stalks the most isolated survivor

</td></tr>
<tr><td>

**📈 Progression & retention**
- XP levels with milestone rewards
- Daily login streaks + daily/weekly quests
- 28-day season pass (free + premium tracks)
- MM2-style crates, rarity skins, kill effects, nametag titles

</td><td>

**🗺️ Content & variety**
- 5 hand-built maps with random-candidate voting
- Round modifiers (Blackout, Low Gravity, Double Coins…)
- 3 special infected abilities (scream / lunge / cloak)
- Global leaderboards + friend invites

</td></tr>
<tr><td>

**🛡️ Live-ops & fair play**
- Server-authoritative everything, **no pay-to-win**
- Movement anti-cheat + rate-limited, validated remotes
- Native Roblox analytics wired to the round loop
- **LiveConfig**: tune timings/prices & enable/disable events from a DataStore — no republish

</td><td>

**♿ Polish & accessibility**
- Cohesive themed UI across every panel
- Separate Music/SFX volume, colorblind mode
- Reduced-motion, UI-scale, full control remapping
- Desktop + mobile + gamepad controls

</td></tr>
</table>

## Tech

- **Luau** (`--!strict`) managed with [Rojo](https://rojo.space); toolchain pinned via [Rokit](https://github.com/rojo-rbx/rokit).
- **Server-authoritative** design — clients send intent, the server decides all damage, currency, and unlocks.
- Player data persists on [ProfileStore](https://github.com/MadStudioRoblox/ProfileStore) (session-locked, vendored).
- **Pure, unit-tested cores**: the round state machine, reward math, Patient-Zero selection, level curve, crate rolls, quests, season pass, daily rewards, anti-cheat classifier, and live-config validation all run as service-free modules with a [Lune](https://lune-org.github.io/docs) test suite (84 tests).
- CI-equivalent gate on every change: `stylua` + `selene` + `lune run tests/run` + `rojo build`, plus a headless `run-in-roblox` boot check.

## Getting started

```bash
rokit install                    # install the pinned toolchain
lune run tests/run               # run the unit tests
rojo build -o INFECTED.rbxlx     # build a place file to open in Studio
rojo serve                       # live-sync into Studio while editing
```

To playtest with bots: open the built place in Studio → **Test → Clients and Servers → Start**. Studio auto-shrinks the round timers so a full loop plays out in under a minute.

## Repo layout

| Path | What's inside |
|------|---------------|
| `src/shared` | `GameConfig` (every tunable) + pure, tested modules: `RoundMachine`, `Rewards`, `PatientZero`, `LevelMath`, `CrateRoll`, `Quests`, `SeasonPass`, `DailyReward`, `AntiCheatMath`, `LiveConfig`, `Keybinds`; validated/rate-limited `Remotes`; `SkinCatalog` + `Titles` |
| `src/server/Services` | `Round`, `Role`, `Combat`, `Bot`, `AntiCheat`, `Map`, `Data`, `Economy`, `Monetization`, `Endgame`, `Retention`, `Leaderboard`, `Analytics`, `LiveConfig` |
| `src/server/Maps` | Building `Kit` + 5 fully-coded maps (Mall, Suburbia, Facility, Warehouse, Metro) |
| `src/client/UI` | HUD, RoleCard, RevealScreen, Shop, MapVote, Juice (game feel), Daily, Quests, Season, Leaderboard, Modifiers, Ability, Social, Nametags, Tutorial, Settings, Sounds, Theme |
| `tests/` | Lune unit suite + `studio-smoke.lua` headless boot check |
| `scripts/publish.sh` | Headless publish to the live place via Roblox Open Cloud |
| `docs/` | `runbook.md` (ops), `research.md` (design research), `publish-checklist.md`, `store-page.md` |

## Deploying

The live game is published via **Roblox Open Cloud** — no Studio needed:

```bash
# requires a ROBLOX_API_KEY with the universe-places (write) scope,
# in the environment or ~/.config/infected/secrets.env
./scripts/publish.sh
```

It builds a binary place file and uploads it as a new *Published* version of the live place. Secrets live outside the repo; nothing sensitive is committed.

## License

MIT — see [`LICENSE`](LICENSE). Built with [Claude Code](https://claude.com/claude-code).
