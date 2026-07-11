#!/bin/bash
# ============================================================
#   Modded Minecraft CLIENT setup (macOS) — for players who JOIN
#
#   Prepares the official Minecraft Launcher: installs Fabric, the same
#   mods as the server (from mods.txt), and a dedicated launcher profile
#   with its own game folder (so it won't touch your other worlds/mods).
#
#   Prerequisites:
#     • Java 21 (JDK)
#     • The Minecraft Launcher, installed and run once (logged in)
#
#   Usage: double-click, or  ./setup-client.command
# ============================================================
set -euo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODS_LIST="$SELF/mods.txt"

# ---------- settings (safe to edit) -------------------------
PROFILE_NAME="Modded"                    # name shown in the launcher's profile picker
CLIENT_DIR="$HOME/Desktop/ModdedClient"  # isolated game dir (own mods/worlds)
MC_VERSION="1.21.1"
FABRIC_LOADER="0.19.3"
FABRIC_INSTALLER="1.1.1"

FABRIC_INSTALLER_URL="https://maven.fabricmc.net/net/fabricmc/fabric-installer/${FABRIC_INSTALLER}/fabric-installer-${FABRIC_INSTALLER}.jar"
FABRIC_API_URL="https://cdn.modrinth.com/data/P7dR8mSH/versions/FHknjVVa/fabric-api-0.116.13%2B1.21.1.jar"

MC_DIR="$HOME/Library/Application Support/minecraft"
PROFILES_JSON="$MC_DIR/launcher_profiles.json"
VERSION_ID="fabric-loader-${FABRIC_LOADER}-${MC_VERSION}"

dl() { # dl <url> <dest> — skip if present AND non-empty
  if [ -f "$2" ] && [ -s "$2" ]; then echo "   ✓ already have $(basename "$2")"; return; fi
  echo "   ↓ $(basename "$2")"
  curl -fSL --retry 3 -o "$2" "$1"
}

install_mods_from_list() { # <list-file> <dest-mods-dir>
  local listfile="$1" dest="$2" line base fname
  [ -f "$listfile" ] || { echo "   ⚠️  $(basename "$listfile") not found — skipping"; return; }
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | tr -d '[:space:]')"
    [ -z "$line" ] && continue
    base="$(basename "$line")"
    fname="$(printf '%b' "${base//%/\\x}")"
    dl "$line" "$dest/$fname"
  done < "$listfile"
}

echo "🎮  Modded Minecraft CLIENT setup"
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
if [ ! -d "$MC_DIR/versions/$VERSION_ID" ]; then
  echo "❌ Fabric client install failed — '$VERSION_ID' not found under versions/."
  exit 1
fi
echo "   ✓ $VERSION_ID installed"

# ---------- 2. mods (same as server, isolated dir) ----------
echo "🧩  Required plumbing mod"
dl "$FABRIC_API_URL" "$CLIENT_DIR/mods/fabric-api-0.116.13+1.21.1.jar"
echo "🧩  Gameplay mods (from mods.txt) → $CLIENT_DIR/mods"
install_mods_from_list "$MODS_LIST" "$CLIENT_DIR/mods"
echo "🧩  Client-only mods (from mods-client.txt)"
install_mods_from_list "$SELF/mods-client.txt" "$CLIENT_DIR/mods"

# ---------- 3. add a dedicated launcher profile -------------
echo "🚀  Adding the '$PROFILE_NAME' launcher profile..."
cp "$PROFILES_JSON" "$PROFILES_JSON.bak.$(date +%s)"
python3 - "$PROFILES_JSON" "$VERSION_ID" "$CLIENT_DIR" "$PROFILE_NAME" <<'PY'
import json, sys, datetime
path, ver, gamedir, pname = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
with open(path) as f:
    data = json.load(f)
now = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.000Z")
data.setdefault("profiles", {})
data["profiles"][pname.lower()] = {
    "name": pname, "type": "custom", "icon": "Grass_Block",
    "lastVersionId": ver, "gameDir": gamedir, "created": now, "lastUsed": now,
}
with open(path, "w") as f:
    json.dump(data, f, indent=2)
print("   ✓ profile '%s' added (game folder: %s)" % (pname, gamedir))
PY

python3 - "$PROFILES_JSON" "$PROFILE_NAME" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert sys.argv[2].lower() in d.get("profiles", {}), "profile missing"
print("   ✓ verified in launcher_profiles.json")
PY

echo
echo "==========================================================="
echo " ✅  Client ready!"
echo
echo "   1. Open the Minecraft Launcher"
echo "   2. Bottom-left profile picker → choose  $PROFILE_NAME  → Play"
echo "   3. Multiplayer → Add Server → the host's address, e.g."
echo "        mc-XXXXXX.play.minekube.net"
echo "==========================================================="
echo
echo "Press Return to close."; read -r
