#!/bin/bash
# ============================================================
#   Start Cobblemon Server   —   double-click this file
#
#   Starts the public connection (Gate) and the world (Fabric).
#   To STOP: close this window, or type  stop  and press Return.
# ============================================================
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FABRIC_DIR="$HERE/FabricModdedServer"
GATE_DIR="$HERE/GateProxy"

clear
echo "🌿  Cobblemon Server"
echo

# ---- safety checks -------------------------------------------------
if ! command -v java >/dev/null 2>&1; then
  echo "❌  Java isn't installed. Install Java 21 first, then try again."
  echo; echo "Press Return to close."; read -r; exit 1
fi
if [ ! -f "$FABRIC_DIR/fabric-server-launch.jar" ]; then
  echo "❌  Can't find the world at:  $FABRIC_DIR"
  echo; echo "Press Return to close."; read -r; exit 1
fi
if [ ! -x "$GATE_DIR/gate" ]; then
  echo "❌  Can't find Gate at:  $GATE_DIR/gate"
  echo; echo "Press Return to close."; read -r; exit 1
fi

# Read the public address straight from Gate's config so it's always correct.
ENDPOINT="$(awk '/^connect:/{f=1} f && /name:/{gsub(/["\x27]/,"",$2); print $2; exit}' "$GATE_DIR/config.yml" 2>/dev/null)"
PUBLIC_ADDR="${ENDPOINT:-<your-endpoint>}.play.minekube.net"

# ---- stop everything cleanly on exit -------------------------------
GATE_PID=""
stop_all() {
  echo
  echo "🛑  Stopping the public connection..."
  [ -n "$GATE_PID" ] && kill "$GATE_PID" 2>/dev/null
  wait 2>/dev/null
  echo "✅  Everything stopped. You can close this window."
}
trap stop_all EXIT INT TERM HUP

# ---- start Gate in the background ----------------------------------
echo "🌐  Starting the public connection (Gate)..."
( cd "$GATE_DIR" && exec ./gate ) > "$GATE_DIR/gate.log" 2>&1 &
GATE_PID=$!

echo
echo "==========================================================="
echo "  Loading the world... watch for the word  Done  below."
echo
echo "  Friends join:   $PUBLIC_ADDR"
echo "  On this Mac:    localhost:25565"
echo
echo "  To STOP: close this window (or type  stop  + Return)."
echo "==========================================================="
echo

# ---- run the world in the foreground (console stays usable) --------
cd "$FABRIC_DIR"
java -Xms2G -Xmx4G -XX:+UseG1GC -jar fabric-server-launch.jar nogui

# Fabric exited (you typed 'stop' or closed the window) -> trap stops Gate.
