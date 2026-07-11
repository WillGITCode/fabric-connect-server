#!/bin/bash
# ============================================================
#   Cobblemon Server — automated setup (macOS)
#
#   Downloads and configures a complete local setup:
#     • Fabric 1.21.1 server + Cobblemon + Fabric API + FabricProxy-Lite
#     • Gate proxy with Minekube Connect (public address, no port-forwarding)
#     • Start / Stop double-click launchers
#
#   Prerequisite: Java 21 (JDK). See README.
#
#   Usage:  double-click this file, or:  ./setup-cobblemon-server.command [install-dir]
#   Default install dir:  ~/CobblemonServer
#
#   Re-runnable: it won't re-download files that already exist.
# ============================================================
set -euo pipefail

# Where this script (and the repo's scripts/ + templates/) live.
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------- settings (safe to edit) -------------------------
BASE_DIR="${1:-$HOME/CobblemonServer}"
MC_VERSION="1.21.1"
FABRIC_LOADER="0.19.3"
FABRIC_INSTALLER="1.1.1"
GATE_VERSION="0.68.26"

# ---------- pinned downloads (verified July 2026) -----------
FABRIC_INSTALLER_URL="https://maven.fabricmc.net/net/fabricmc/fabric-installer/${FABRIC_INSTALLER}/fabric-installer-${FABRIC_INSTALLER}.jar"
SERVER_JAR_URL="https://piston-data.mojang.com/v1/objects/59353fb40c36d304f2035d51e7d6e6baa98dc05c/server.jar"
COBBLEMON_URL="https://cdn.modrinth.com/data/MdwFAVRL/versions/kF7CvxTo/Cobblemon-fabric-1.7.3%2B1.21.1.jar"
FABRIC_API_URL="https://cdn.modrinth.com/data/P7dR8mSH/versions/FHknjVVa/fabric-api-0.116.13%2B1.21.1.jar"
FABRICPROXY_URL="https://cdn.modrinth.com/data/8dI2tmqs/versions/KqB3UA0q/FabricProxy-Lite-2.10.1.jar"

# ---------- derived -----------------------------------------
case "$(uname -m)" in
  arm64)  GARCH="arm64" ;;
  x86_64) GARCH="amd64" ;;
  *) echo "❌ Unsupported CPU: $(uname -m)"; exit 1 ;;
esac
GATE_URL="https://github.com/minekube/gate/releases/download/v${GATE_VERSION}/gate_${GATE_VERSION}_darwin_${GARCH}"

FABRIC_DIR="$BASE_DIR/FabricModdedServer"
GATE_DIR="$BASE_DIR/GateProxy"
# Globally-unique-ish endpoint name so it won't collide on the Connect network.
ENDPOINT_NAME="cobblemon-$(openssl rand -hex 3)"
SECRET="$(openssl rand -hex 16)"

dl() { # dl <url> <dest>  — skip if already present
  if [ -f "$2" ]; then echo "   ✓ already have $(basename "$2")"; return; fi
  echo "   ↓ $(basename "$2")"
  curl -fSL --retry 3 -o "$2" "$1"
}

render() { # render <template> <dest>  — substitute __SECRET__ / __ENDPOINT__
  sed -e "s|__SECRET__|${SECRET}|g" -e "s|__ENDPOINT__|${ENDPOINT_NAME}|g" "$1" > "$2"
}

echo "🌿  Cobblemon Server setup"
echo "    Installing to: $BASE_DIR"
echo

# ---------- preflight ---------------------------------------
for tool in java curl openssl sed; do
  command -v "$tool" >/dev/null 2>&1 || { echo "❌ Missing required tool: $tool"; exit 1; }
done
JV="$(java -version 2>&1)"
echo "☕ Java: ${JV%%$'\n'*}"
case "$JV" in
  *'"21'*) : ;;
  *) echo "   ⚠️  This needs Java 21 for Minecraft $MC_VERSION. If setup fails, install JDK 21." ;;
esac
echo

mkdir -p "$FABRIC_DIR" "$GATE_DIR"

# ---------- Fabric server -----------------------------------
echo "📦  Fabric server ($MC_VERSION, loader $FABRIC_LOADER)"
INSTALLER_JAR="$BASE_DIR/fabric-installer-${FABRIC_INSTALLER}.jar"
dl "$FABRIC_INSTALLER_URL" "$INSTALLER_JAR"
if [ ! -f "$FABRIC_DIR/fabric-server-launch.jar" ]; then
  echo "   • running Fabric installer..."
  java -jar "$INSTALLER_JAR" server -mcversion "$MC_VERSION" -loader "$FABRIC_LOADER" -dir "$FABRIC_DIR" >/dev/null
fi
dl "$SERVER_JAR_URL" "$FABRIC_DIR/server.jar"

# ---------- EULA + server.properties ------------------------
echo "📝  Config files"
printf 'eula=true\n' > "$FABRIC_DIR/eula.txt"
if [ ! -f "$FABRIC_DIR/server.properties" ]; then
cat > "$FABRIC_DIR/server.properties" <<PROPS
#Minecraft server properties
server-port=25566
online-mode=false
motd=Cobblemon Server
max-players=20
difficulty=easy
gamemode=survival
spawn-protection=0
view-distance=10
simulation-distance=10
allow-nether=true
pvp=true
level-name=world
PROPS
fi

# ---------- FabricProxy-Lite config (from template) ---------
mkdir -p "$FABRIC_DIR/config"
render "$SELF/templates/FabricProxy-Lite.toml" "$FABRIC_DIR/config/FabricProxy-Lite.toml"

# ---------- mods --------------------------------------------
echo "🧩  Mods"
mkdir -p "$FABRIC_DIR/mods"
dl "$FABRIC_API_URL"   "$FABRIC_DIR/mods/fabric-api-0.116.13+1.21.1.jar"
dl "$FABRICPROXY_URL"  "$FABRIC_DIR/mods/FabricProxy-Lite-2.10.1.jar"
dl "$COBBLEMON_URL"    "$FABRIC_DIR/mods/Cobblemon-fabric-1.7.3+1.21.1.jar"   # ~129 MB, be patient

# ---------- Gate proxy (from template) ----------------------
echo "🌐  Gate proxy ($GATE_VERSION, darwin/$GARCH)"
dl "$GATE_URL" "$GATE_DIR/gate"
chmod +x "$GATE_DIR/gate"
xattr -dr com.apple.quarantine "$GATE_DIR/gate" 2>/dev/null || true
render "$SELF/templates/gate-config.yml" "$GATE_DIR/config.yml"

# ---------- Start / Stop launchers (copied from repo) -------
echo "🚀  Launchers"
cp "$SELF/scripts/Start Cobblemon Server.command" "$BASE_DIR/"
cp "$SELF/scripts/Stop Cobblemon Server.command"  "$BASE_DIR/"
chmod +x "$BASE_DIR/Start Cobblemon Server.command" "$BASE_DIR/Stop Cobblemon Server.command"

# ---------- done --------------------------------------------
echo
echo "==========================================================="
echo " ✅  Setup complete!"
echo
echo "   Folder:          $BASE_DIR"
echo "   Public address:  ${ENDPOINT_NAME}.play.minekube.net"
echo
echo "   To play: open $BASE_DIR in Finder and double-click"
echo "            \"Start Cobblemon Server.command\""
echo "==========================================================="
echo
echo "Press Return to close."; read -r
