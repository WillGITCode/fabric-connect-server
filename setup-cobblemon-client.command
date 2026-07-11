#!/bin/bash
# ============================================================
#   Cobblemon CLIENT setup (macOS) — for players who want to JOIN
#
#   Prepares the official Minecraft Launcher to join the Cobblemon
#   server: installs Fabric, the matching client mods, and a dedicated
#   "Cobblemon" launcher profile with its own game folder (so it won't
#   touch your other worlds/mods).
#
#   Prerequisites:
#     • Java 21 (JDK)
#     • The Minecraft Launcher, installed and run once (logged in)
#
#   Usage: double-click, or  ./setup-cobblemon-client.command
# ============================================================
set -euo pipefail

MC_VERSION="1.21.1"
FABRIC_LOADER="0.19.3"
FABRIC_INSTALLER="1.1.1"

# pinned downloads (same versions as the server)
FABRIC_INSTALLER_URL="https://maven.fabricmc.net/net/fabricmc/fabric-installer/${FABRIC_INSTALLER}/fabric-installer-${FABRIC_INSTALLER}.jar"
COBBLEMON_URL="https://cdn.modrinth.com/data/MdwFAVRL/versions/kF7CvxTo/Cobblemon-fabric-1.7.3%2B1.21.1.jar"
FABRIC_API_URL="https://cdn.modrinth.com/data/P7dR8mSH/versions/FHknjVVa/fabric-api-0.116.13%2B1.21.1.jar"

MC_DIR="$HOME/Library/Application Support/minecraft"
PROFILES_JSON="$MC_DIR/launcher_profiles.json"
CLIENT_DIR="$HOME/CobblemonClient"                 # isolated game dir (own mods/worlds)
VERSION_ID="fabric-loader-${FABRIC_LOADER}-${MC_VERSION}"

dl() { # dl <url> <dest> — skip only if present AND non-empty
  if [ -f "$2" ] && [ -s "$2" ]; then echo "   ✓ already have $(basename "$2")"; return; fi
  echo "   ↓ $(basename "$2")"
  curl -fSL --retry 3 -o "$2" "$1"
}

echo "🎮  Cobblemon CLIENT setup"
echo

# ---------- preflight ---------------------------------------
for t in java curl python3; do
  command -v "$t" >/dev/null 2>&1 || { echo "❌ Missing required tool: $t"; exit 1; }
done
JV="$(java -version 2>&1)"; echo "☕ Java: ${JV%%$'\n'*}"
case "$JV" in *'"21'*) : ;; *) echo "   ⚠️  Needs Java 21 for Minecraft $MC_VERSION." ;; esac
if [ ! -f "$PROFILES_JSON" ]; then
  echo "❌ Minecraft Launcher isn't set up yet."
  echo "   Install it from minecraft.net, run it once and log in, then re-run this."
  echo; echo "Press Return to close."; read -r; exit 1
fi
echo
echo "⚠️  QUIT the Minecraft Launcher now — it rewrites its profiles when it closes,"
echo "    which would wipe the profile this script adds."
echo "    Press Return once the launcher is fully closed."
read -r

mkdir -p "$CLIENT_DIR/mods"

# ---------- 1. Fabric into the launcher ---------------------
echo "📦  Installing Fabric $FABRIC_LOADER for Minecraft $MC_VERSION into the launcher..."
dl "$FABRIC_INSTALLER_URL" "$CLIENT_DIR/fabric-installer-${FABRIC_INSTALLER}.jar"
java -jar "$CLIENT_DIR/fabric-installer-${FABRIC_INSTALLER}.jar" client \
  -dir "$MC_DIR" -mcversion "$MC_VERSION" -loader "$FABRIC_LOADER" >/dev/null
# validate the installer actually produced the version
if [ ! -d "$MC_DIR/versions/$VERSION_ID" ]; then
  echo "❌ Fabric client install failed — '$VERSION_ID' not found under versions/."
  exit 1
fi
echo "   ✓ $VERSION_ID installed"

# ---------- 2. client mods (isolated) -----------------------
echo "🧩  Client mods → $CLIENT_DIR/mods"
dl "$FABRIC_API_URL" "$CLIENT_DIR/mods/fabric-api-0.116.13+1.21.1.jar"
dl "$COBBLEMON_URL"  "$CLIENT_DIR/mods/Cobblemon-fabric-1.7.3+1.21.1.jar"   # ~129 MB

# ---------- 3. add a dedicated launcher profile -------------
echo "🚀  Adding the 'Cobblemon' launcher profile..."
cp "$PROFILES_JSON" "$PROFILES_JSON.bak.$(date +%s)"    # backup first
python3 - "$PROFILES_JSON" "$VERSION_ID" "$CLIENT_DIR" <<'PY'
import json, sys, datetime
path, ver, gamedir = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    data = json.load(f)
now = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.000Z")
data.setdefault("profiles", {})
data["profiles"]["cobblemon"] = {
    "name": "Cobblemon",
    "type": "custom",
    "icon": "Grass_Block",
    "lastVersionId": ver,
    "gameDir": gamedir,
    "created": now,
    "lastUsed": now,
}
with open(path, "w") as f:
    json.dump(data, f, indent=2)
print("   ✓ profile 'Cobblemon' added (game folder: %s)" % gamedir)
PY

# validate the profile landed
python3 - "$PROFILES_JSON" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert "cobblemon" in d.get("profiles", {}), "profile missing"
print("   ✓ verified in launcher_profiles.json")
PY

echo
echo "==========================================================="
echo " ✅  Client ready!"
echo
echo "   1. Open the Minecraft Launcher"
echo "   2. Bottom-left profile picker → choose  Cobblemon  → Play"
echo "   3. Multiplayer → Add Server → the host's address, e.g."
echo "        cobblemon-XXXX.play.minekube.net"
echo "==========================================================="
echo
echo "Press Return to close."; read -r
