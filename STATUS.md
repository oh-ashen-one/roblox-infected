# Build status vs Definition of Done

Updated 2026-07-17 (published PRIVATE to Roblox as "INFECTED - Hidden Zombie Among You"; latest build with all fixes + sounds is live on the cloud place).

| DoD item | Status |
| --- | --- |
| Round flow end-to-end multi-client | ✅ observed live (Server and Clients, 2 players): intermission → vote → round → PZ role card → conversion → INFECTED win → reveal w/ PZ unmask → next intermission |
| 3 maps built, streamed, voted | ✅ vote UI live; Suburbia observed loading with night lighting; Mall/Facility rotation pending hands-on pass |
| Server-auth combat + anti-cheat observed | ⏳ conversion kills observed; gun/knife feel + anti-cheat rejections = Hari's hands-on pass |
| Economy/shop/crates/skins persist across rejoin | ✅ coin payouts observed persisting across rounds (35/70 coins); crates/skins = hands-on pass |
| Desktop + mobile UI | ✅ desktop HUD observed live; mobile touch layout verified in iPhone XR Device Emulator |
| Gamepasses + dev products, idempotent receipts | ⏳ Creator Hub (web login needed): create products, wire IDs, test-purchase |
| CI green | ✅ |
| Published public + real round played | ⏳ published PRIVATE; public flip needs Creator Hub: eligibility questionnaire, Max Players 30, icon/thumbnails, then Access → Public |
| Runbook | ✅ docs/runbook.md (+ docs/publish-checklist.md) |

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
