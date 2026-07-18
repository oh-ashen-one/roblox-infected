#!/usr/bin/env bash
# Headless publish to the live INFECTED place via Roblox Open Cloud — no Studio, no
# computer control. Builds a binary place file and uploads it as a new PUBLISHED version.
#
# One-time setup (you do this in a browser):
#   1. create.roblox.com -> Creator Hub -> Open Cloud -> API Keys -> Create API Key.
#   2. Add the "universe-places" / Place Management API, scope: write, for the INFECTED
#      universe (10518289514). Add your IP (or 0.0.0.0/0) to the allowed list. Save.
#   3. Put the key where this script can read it, either:
#        export ROBLOX_API_KEY=xxxxx
#      or in ~/.config/infected/secrets.env  (ROBLOX_API_KEY=xxxxx)
#
# Then:  ./scripts/publish.sh            # publishes (asks nothing else)
#
# This overwrites the LIVE public game. Playtest first (Studio Test -> Clients/Servers).

set -euo pipefail

UNIVERSE_ID=10518289514
PLACE_ID=78267419085369
PLACE_FILE=INFECTED.rbxl

cd "$(dirname "$0")/.."

# Load the key from the secrets file if not already in the environment.
if [[ -z "${ROBLOX_API_KEY:-}" && -f "$HOME/.config/infected/secrets.env" ]]; then
	# shellcheck disable=SC1091
	source "$HOME/.config/infected/secrets.env"
fi

if [[ -z "${ROBLOX_API_KEY:-}" ]]; then
	echo "ERROR: ROBLOX_API_KEY is not set. See the setup notes at the top of this script." >&2
	exit 1
fi

echo "==> Building binary place file ($PLACE_FILE)"
rojo build -o "$PLACE_FILE"

echo "==> Publishing to place $PLACE_ID (universe $UNIVERSE_ID) as a PUBLISHED version"
HTTP_CODE=$(curl -sS -o /tmp/infected_publish_resp.json -w "%{http_code}" \
	-X POST \
	"https://apis.roblox.com/universes/v1/${UNIVERSE_ID}/places/${PLACE_ID}/versions?versionType=Published" \
	-H "x-api-key: ${ROBLOX_API_KEY}" \
	-H "Content-Type: application/octet-stream" \
	--data-binary @"${PLACE_FILE}")

echo "HTTP $HTTP_CODE"
cat /tmp/infected_publish_resp.json
echo

if [[ "$HTTP_CODE" == "200" ]]; then
	echo "==> Published. The live game now runs this build."
else
	echo "==> Publish failed (see response above). Common causes: key missing the Place" >&2
	echo "    Management write scope for universe ${UNIVERSE_ID}, IP not allow-listed, or" >&2
	echo "    the key belongs to a different account than the game owner (solashenone)." >&2
	exit 1
fi
