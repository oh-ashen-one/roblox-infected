# Publish checklist (Phase 7)

Run top to bottom on ship day. Hari approves prices; everything else is mechanical.

## 1. Publish the place (Studio)

1. Open `INFECTED.rbxlx` (latest `rojo build`) in Studio.
2. File → **Publish to Roblox** → Create new experience → name **INFECTED — Hidden Zombie Among You**.
3. Game Settings (⚙):
   - **Basic Info**: description from `docs/store-page.md`; genre Horror; devices: Computer, Phone, Tablet, Console.
   - **Icon**: upload `assets/icon.png`. **Thumbnails**: `assets/thumbnail-mall.png`, `thumbnail-suburbia.png`, `thumbnail-facility.png`.
   - **Places → Start Place → Max Players 30**; social slots 2; join queue on.
   - **Security**: Enable Studio Access to API Services (DataStores in Studio tests); HTTP off.
   - **Permissions**: PRIVATE until the smoke pass below is done.
4. Publish. Note the **experience/universe ID** and **place ID**.

## 2. Create products (Creator Dashboard → the experience)

Prices per `docs/store-page.md` (Hari approves).

- Gamepasses (Associated Items → Passes): 2x Coins 199, XP Boost 149, VIP 349, Radio 99.
- Dev products (Monetization → Developer Products): Coins1000 49, Coins5000 199, Coins12000 399, CrateKey1 79, CrateKey5 349, PatientZeroToken 129.
- Paste every ID into `src/shared/GameConfig.luau → Products`, `rojo build`, republish.

## 3. Private smoke pass

1. In Studio: Test → Server and Clients, 4 players — full round on each map, one crate purchase with coins, one Robux **test purchase** of a dev product (Studio sandbox — no real charge) and confirm grant + no double-grant on retry.
2. Join the PRIVATE published game from the Roblox app/player as `solashenone` — one full round (DataStores now real: coins must survive rejoin).

## 4. Go public + first round

1. Creator Dashboard → Permissions → **Public**.
2. Join from the Roblox player; play a full public round; confirm the server shows 30 max players.
3. Watch Creator Dashboard → Error Report for the first hour (runbook has the triage list).

## 5. Post-launch

- Tag the release: `git tag v1.0-launch && git push --tags`.
- Follow `docs/runbook.md` for daily monitoring.
