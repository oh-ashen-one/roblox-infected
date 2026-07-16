# INFECTED — Post-Launch Runbook

## Daily monitoring

- **Creator Dashboard → Performance**: server crash rate, memory (should stay well under 6 GB — maps are ~2-4k parts each, cloned one at a time), average FPS. Alarm point: crash rate > 1%.
- **Creator Dashboard → Engagement**: D1 retention, average session length, funnel (visit → played a round → played 3+ rounds). The genre's health signal is *rounds per session* — under 2 means rounds feel bad; check round-length telemetry.
- **Monetization**: crate opens per DAU, gamepass attach rate. MM2-pattern reference: most revenue comes from crate keys + 2x coins.
- **Error Report** (Creator Dashboard → Error Report): sort by count. Server errors in `CombatService`/`RoleService` are round-breaking — hotfix same day.

## Exploit-report triage

1. Reports of speed/teleport hacking → check `AntiCheatService` kick logs (search server logs for "Suspicious activity"). If hackers survive, lower `Movement.MaxToleratedSpeed` slack or `KICK_THRESHOLD` in `AntiCheatService.luau`.
2. Reports of impossible kills (cross-map conversions) → verify `ORIGIN_TOLERANCE` in `CombatService.luau` and the knife `MaxThrowRange`; both are server-checked, so an impossible kill means a validation gap — reproduce in Studio first.
3. Duped coins/skins → ProfileStore session locking makes classic dupes hard; check `receipts` handling in `MonetizationService` and look for repeated `PurchaseId` grants.
4. Always patch server-side. Never ship a client-side "fix" for an exploit.

## Hotfix procedure

1. Fix in the repo, run `stylua src tests && selene src && lune run tests/run && rojo build -o INFECTED.rbxlx` (or push and let CI verify).
2. Open the place in Studio (`rojo serve` + sync, or open the built rbxlx and File → Publish to the SAME place).
3. Publish → Creator Dashboard → **Restart servers for updates** (players re-join into patched servers; ProfileStore handles the session handoff).
4. Tag the commit: `git tag hotfix-YYYYMMDD && git push --tags`.

## Balance levers (all in `src/shared/GameConfig.luau`)

- Rounds ending too fast with infected winning → raise `SurvivorMaxHealth`, lower zombie `walkSpeedMult`, or shrink `SecondsPerConversion`.
- Survivors camping to victory → raise `LastSurvivorsPingCount`, shorten `PingIntervalSeconds`, buff Screamer cooldown.
- Economy inflation → lower per-event rewards or raise `CrateCostCoins`. Never touch owned inventories.

## D1 retention levers

- First-session experience: new players should hit a round within 30s of joining (check `MinPlayersToStart` fill rates; consider lowering off-peak).
- Add daily-streak coin bonus (profile already tracks it) if D1 < 20%.
- Content cadence: MM2/STK pattern is a new crate/skin batch every 2-4 weeks; skins are data-only (`SkinCatalog.luau`) — no client update needed beyond publish.

## Infra facts

- Max players 30 per server, join queue on, 1-2 social slots reserved (Game Settings).
- Data: ProfileStore `PlayerData_v1`. NEVER change the store name casually — that orphans all player data. Schema changes go through `PROFILE_TEMPLATE` (new keys auto-reconcile).
- Maps stream (StreamingEnabled, min 256 / target 512); active map is a per-round clone — memory leaks would show as monotonic memory growth across rounds.
