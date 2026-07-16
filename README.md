# INFECTED 🧟

A 30-player hidden-infection round game for Roblox, in the spirit of COD's Infected mode with a Murder Mystery twist:

- 30 players join a lobby. When a round starts, **one player is secretly infected** — nobody knows who, not even by looks.
- The hidden infected hunts with **throwing knives**. Every kill converts the victim into a visible zombie on the infected team.
- Survivors carry **real guns** and must figure out who to trust while the horde grows.
- When the timer runs out, the round ends with a full **reveal board**: who was the original infected, who survived, most kills, first blood, last survivor.

## Tech

- Fully scripted, managed with [Rojo](https://rojo.space) (`rojo serve` + Roblox Studio sync plugin).
- Toolchain pinned via [Rokit](https://github.com/rojo-rbx/rokit) — run `rokit install` after cloning.
- Server-authoritative combat, ProfileStore persistence, StreamingEnabled map.

## Getting started

```bash
rokit install
rojo build -o INFECTED.rbxlx   # then open in Studio
rojo serve                      # live sync while editing
```

## Repo layout

- `default.project.json` — Rojo project map (StreamingEnabled workspace)
- `src/shared` — GameConfig (every tunable), RoundMachine + Rewards + PatientZero +
  LevelMath + CrateRoll (pure, unit-tested), Remotes (validated + rate-limited),
  SkinCatalog
- `src/server/Services` — Round, Role, Combat (server-auth guns/knives/melee),
  AntiCheat, Map (vote + clone lifecycle), Data (ProfileStore), Economy,
  Monetization (idempotent ProcessReceipt), Endgame (pings + Last Stand)
- `src/server/Maps` — Kit + three fully-coded maps (Mall, Suburbia, Facility)
- `src/client` — CombatController, HUD, RoleCard, RevealScreen, MapVote, Shop,
  Pings, Touch controls
- `tests/` — Lune test suite (`lune run tests/run`); CI runs selene, stylua,
  tests, and a rojo build on every push

## Docs

- `MASTER-PROMPT.md` — the full build spec
- `docs/research.md` — competitor/design research the spec is based on
- `docs/runbook.md` — post-launch monitoring, hotfix, and balance guide
