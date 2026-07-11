#!/bin/bash
# ============================================================
#   Stop Cobblemon Server   —   double-click this file
#
#   Safety net: force-stops the world + public connection if a
#   window was closed without them shutting down properly.
# ============================================================

echo "🛑  Stopping the Cobblemon server..."

# Only match OUR processes, not anything else on the machine.
pkill -x 'gate'                      2>/dev/null && echo "   • public connection (Gate) stopped"
pkill -f 'fabric-server-launch.jar'  2>/dev/null && echo "   • world (Fabric) stopped"

sleep 1
echo "✅  Done. You can close this window."
sleep 1
