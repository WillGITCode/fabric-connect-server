#!/bin/bash
# ============================================================
#   Modded Minecraft server — automated setup (macOS)
#
#   Downloads and configures a complete local setup:
#     • Fabric 1.21.1 server + your mods (from mods.txt)
#     • Gate proxy with Minekube Connect (public address, no port-forwarding)
#     • Start / Stop double-click launchers
#
#   Prerequisite: Java 21 (JDK). See README.
#
#   Usage:  double-click this file, or:  ./setup-server.command [install-dir]
#   Default install dir:  ~/Desktop/ModdedServer
#
#   Re-runnable: it won't re-download files that already exist.
# ============================================================
set -euo pipefail

# Where this script (and mods.txt, scripts/, templates/) live.
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODS_LIST="$SELF/mods.txt"

# ---------- settings (safe to edit) -------------------------
BASE_DIR="${1:-$HOME/Desktop/ModdedServer}"
ENDPOINT_PREFIX="mc"            # public address will be  <prefix>-xxxxxx.play.minekube.net
MC_VERSION="1.21.1"
FABRIC_LOADER="0.19.3"
FABRIC_INSTALLER="1.1.1"
GATE_VERSION="0.68.26"

# ---------- pinned "plumbing" downloads (always installed) --
FABRIC_INSTALLER_URL="https://maven.fabricmc.net/net/fabricmc/fabric-installer/${FABRIC_INSTALLER}/fabric-installer-${FABRIC_INSTALLER}.jar"
SERVER_JAR_URL="https://piston-data.mojang.com/v1/objects/59353fb40c36d304f2035d51e7d6e6baa98dc05c/server.jar"
FABRIC_API_URL="https://cdn.modrinth.com/data/P7dR8mSH/versions/FHknjVVa/fabric-api-0.116.13%2B1.21.1.jar"
FABRICPROXY_URL="https://cdn.modrinth.com/data/8dI2tmqs/versions/KqB3UA0q/FabricProxy-Lite-2.10.1.jar"

# ---------- derived -----------------------------------------
case "$(uname -m)" in
  arm64)  GARCH="arm64" ;;
  x86_64) GARCH="amd64" ;;
  *) echo "❌ Unsupported CPU: $(uname -m)"; exit 1 ;;
esac
GATE_URL="https://github.com/minekube/gate/releases/download/v${GATE_VERSION}/gate_${GATE_VERSION}_darwin_${GARCH}"

# If installing to the DEFAULT location and it already exists, make a fresh
# non-colliding instance (ModdedServer-2, -3, …) instead of clobbering it.
INSTANCE=1
if [ -z "${1:-}" ]; then
  while [ -e "$BASE_DIR" ]; do INSTANCE=$((INSTANCE + 1)); BASE_DIR="$HOME/Desktop/ModdedServer-$INSTANCE"; done
fi

FABRIC_DIR="$BASE_DIR/FabricModdedServer"
GATE_DIR="$BASE_DIR/GateProxy"
SERVER_NAME="$(basename "$BASE_DIR")"                        # e.g. ModdedServer, ModdedServer-2
ENDPOINT_NAME="${ENDPOINT_PREFIX}-$(openssl rand -hex 3)"   # globally-unique public address
SECRET="$(openssl rand -hex 16)"

# Give each instance its own ports so several servers can run at the same time.
port_free() { ! lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1; }
PROXY_PORT=$(( 25565 + (INSTANCE - 1) * 2 ))
while ! port_free "$PROXY_PORT" || ! port_free "$((PROXY_PORT + 1))"; do PROXY_PORT=$((PROXY_PORT + 2)); done
BACKEND_PORT=$((PROXY_PORT + 1))

dl() { # dl <url> <dest> — skip only if present and (for jars) a valid zip; else (re)download + verify
  if [ -f "$2" ] && [ -s "$2" ]; then
    case "$2" in
      *.jar) if unzip -tqq "$2" >/dev/null 2>&1; then echo "   ✓ already have $(basename "$2")"; return; fi
             echo "   ⚠️  $(basename "$2") is incomplete/corrupt — re-downloading" ;;
      *) echo "   ✓ already have $(basename "$2")"; return ;;
    esac
  fi
  echo "   ↓ $(basename "$2")"
  curl -fSL --retry 3 -o "$2" "$1"
  case "$2" in
    *.jar) unzip -tqq "$2" >/dev/null 2>&1 || { echo "   ❌ $(basename "$2") downloaded corrupt (incomplete zip). Check your connection and re-run."; exit 1; } ;;
  esac
}

render() { # render <template> <dest>  — fill in secret / endpoint / ports / name
  sed -e "s|__SECRET__|${SECRET}|g" -e "s|__ENDPOINT__|${ENDPOINT_NAME}|g" \
      -e "s|__PROXYPORT__|${PROXY_PORT}|g" -e "s|__BACKENDPORT__|${BACKEND_PORT}|g" \
      -e "s|__MOTD__|${SERVER_NAME}|g" "$1" > "$2"
}

install_mods_from_list() { # install_mods_from_list <list-file> <dest-mods-dir>
  local listfile="$1" dest="$2" line base fname
  [ -f "$listfile" ] || { echo "   ⚠️  $(basename "$listfile") not found — skipping"; return; }
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"                       # strip comments
    line="$(printf '%s' "$line" | tr -d '[:space:]')"
    [ -z "$line" ] && continue
    base="$(basename "$line")"
    fname="$(printf '%b' "${base//%/\\x}")"   # url-decode (e.g. %2B -> +)
    dl "$line" "$dest/$fname"
  done < "$listfile"
}

# Keep a log file so problems can be diagnosed after the window closes.
mkdir -p "$BASE_DIR"
LOGFILE="$BASE_DIR/setup-server.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "🧱  Modded Minecraft server setup"
echo "    Installing to: $BASE_DIR"
echo "    Log:           $LOGFILE"
echo

# ---------- preflight ---------------------------------------
for tool in java curl openssl sed unzip; do
  command -v "$tool" >/dev/null 2>&1 || { echo "❌ Missing required tool: $tool"; exit 1; }
done
JV="$(java -version 2>&1)"
echo "☕ Java: ${JV%%$'\n'*}"
case "$JV" in
  *'"21'*) : ;;
  *) echo "   ⚠️  This needs Java 21 for Minecraft $MC_VERSION. If setup fails, install JDK 21." ;;
esac
echo

mkdir -p "$FABRIC_DIR/mods" "$FABRIC_DIR/config" "$GATE_DIR"

# ---------- Fabric server -----------------------------------
echo "📦  Fabric server ($MC_VERSION, loader $FABRIC_LOADER)"
INSTALLER_JAR="$BASE_DIR/fabric-installer-${FABRIC_INSTALLER}.jar"
dl "$FABRIC_INSTALLER_URL" "$INSTALLER_JAR"
if [ ! -f "$FABRIC_DIR/fabric-server-launch.jar" ]; then
  echo "   • running Fabric installer..."
  java -jar "$INSTALLER_JAR" server -mcversion "$MC_VERSION" -loader "$FABRIC_LOADER" -dir "$FABRIC_DIR" >/dev/null
fi
[ -f "$FABRIC_DIR/fabric-server-launch.jar" ] || { echo "❌ Fabric server install failed (fabric-server-launch.jar missing)."; exit 1; }
dl "$SERVER_JAR_URL" "$FABRIC_DIR/server.jar"

# ---------- EULA + server.properties ------------------------
echo "📝  Config files"
printf 'eula=true\n' > "$FABRIC_DIR/eula.txt"
if [ ! -f "$FABRIC_DIR/server.properties" ]; then
cat > "$FABRIC_DIR/server.properties" <<PROPS
#Minecraft server properties
server-port=$BACKEND_PORT
online-mode=false
motd=$SERVER_NAME
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

# FabricProxy-Lite config (from template)
render "$SELF/templates/FabricProxy-Lite.toml" "$FABRIC_DIR/config/FabricProxy-Lite.toml"

# ---------- mods --------------------------------------------
echo "🧩  Required plumbing mods"
dl "$FABRIC_API_URL"   "$FABRIC_DIR/mods/fabric-api-0.116.13+1.21.1.jar"
dl "$FABRICPROXY_URL"  "$FABRIC_DIR/mods/FabricProxy-Lite-2.10.1.jar"
echo "🧩  Gameplay mods (from mods.txt)"
install_mods_from_list "$MODS_LIST" "$FABRIC_DIR/mods"

# ---------- Gate proxy (from template) ----------------------
echo "🌐  Gate proxy ($GATE_VERSION, darwin/$GARCH)"
dl "$GATE_URL" "$GATE_DIR/gate"
chmod +x "$GATE_DIR/gate"
xattr -dr com.apple.quarantine "$GATE_DIR/gate" 2>/dev/null || true
render "$SELF/templates/gate-config.yml" "$GATE_DIR/config.yml"

# ---------- Start / Stop launchers (copied from repo) -------
echo "🚀  Launchers"
cp "$SELF/scripts/Start Server.command" "$BASE_DIR/"
cp "$SELF/scripts/Stop Server.command"  "$BASE_DIR/"
chmod +x "$BASE_DIR/Start Server.command" "$BASE_DIR/Stop Server.command"

# ---------- done --------------------------------------------
echo
echo "==========================================================="
echo " ✅  Setup complete!"
echo
echo "   Folder:          $BASE_DIR"
echo "   Public address:  ${ENDPOINT_NAME}.play.minekube.net"
echo "   Local ports:     proxy ${PROXY_PORT}, world ${BACKEND_PORT}"
echo
echo "   To play: open $BASE_DIR in Finder and double-click"
echo "            \"Start Server.command\""
echo "==========================================================="
echo
echo "Press Return to close."; read -r
