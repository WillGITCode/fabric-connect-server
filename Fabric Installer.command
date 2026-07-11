#!/bin/bash
# ============================================================
#   Fabric Installer   —   double-click this file
#
#   Opens the Fabric installer's window. macOS can't double-click a
#   ".jar" directly (it looks for Java in the wrong place), so this
#   little wrapper launches it with your installed Java instead.
#
#   Use it to make a server or client for OTHER Minecraft versions,
#   or to experiment. (The one-click setup-server / setup-client
#   scripts don't need this — they run the installer for you.)
# ============================================================
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FABRIC_INSTALLER="1.1.1"
JAR="$HERE/fabric-installer-${FABRIC_INSTALLER}.jar"
URL="https://maven.fabricmc.net/net/fabricmc/fabric-installer/${FABRIC_INSTALLER}/fabric-installer-${FABRIC_INSTALLER}.jar"

clear
echo "🧵  Fabric Installer"
echo

if ! command -v java >/dev/null 2>&1; then
  echo "❌  Java isn't installed. Install Java 21 first, then try again."
  echo; echo "Press Return to close."; read -r; exit 1
fi

if [ ! -f "$JAR" ]; then
  echo "⬇️  Downloading the Fabric installer (first time only)..."
  curl -fSL --retry 3 -o "$JAR" "$URL"
fi

echo "🪟  Opening the installer window..."
echo "    (Choose the Server or Client tab, pick a Minecraft version, then Install.)"
echo "    You can close this Terminal window once the installer window is open."
java -jar "$JAR"
