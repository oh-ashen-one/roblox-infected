# Build status vs Definition of Done

Updated 2026-07-16 (all code pushed, CI green — 37 tests, selene/stylua clean).

| DoD item | Status |
| --- | --- |
| Round flow end-to-end multi-client | ⏳ code complete + solo-boot verified headless; **needs Studio "Clients and Servers" playtest** |
| 3 maps built, streamed, voted | ✅ code complete (Mall/Suburbia/Facility); rotation logic in MapService — verify visuals in playtest |
| Server-auth combat + anti-cheat observed | ⏳ implemented; needs playtest observation |
| Economy/shop/crates/skins persist across rejoin | ⏳ implemented on ProfileStore; needs playtest |
| Desktop + mobile UI | ✅ implemented (HUD/role card/reveal/vote/shop/settings/touch/gamepad) — verify in playtest |
| Gamepasses + dev products, idempotent receipts | ⏳ code + pricing sheet ready (docs/store-page.md); products created at publish; IDs → GameConfig.Products |
| CI green | ✅ |
| Published public + real round played | ❌ blocked: needs Studio UI (computer-use) |
| Runbook | ✅ docs/runbook.md |

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
