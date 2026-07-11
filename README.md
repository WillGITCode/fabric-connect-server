# Modded Minecraft Server — play with friends, one click

Run a **modded Minecraft server** your friends can join from anywhere — **no port-forwarding and
without exposing your home IP**. Your Mac dials out to [Minekube Connect](https://connect.minekube.com);
friends just type a `something.play.minekube.net` address.

Ships ready to run **Cobblemon** as a demo — [swap in any Fabric 1.21.1 mods](#-change-the-mods) you want.

---

## ✅ Before you start

- A **Mac**
- **Java 21** — [download the macOS installer](https://adoptium.net/temurin/releases/?version=21) (pick the `.pkg`) and double-click it. That's the only thing to install by hand.

## 1. Get these files

- **Easiest (no terminal):** on the GitHub page → green **Code** button → **Download ZIP** → double-click the ZIP to unzip.
- **Terminal:** `git clone https://github.com/WillGITCode/fabric-connect-server.git`

## 2. Host the server (the person running it)

1. Double-click **`setup-server.command`** — downloads everything (~200 MB, a few minutes) into a new **`~/Desktop/ModdedServer`** folder.
2. Open the **ModdedServer** folder on your Desktop and double-click **`Start Server.command`**.
3. Wait for the word **`Done`**. The window shows your address (e.g. `mc-ab12cd.play.minekube.net`) — share it with friends.
4. **Stop:** close that window, or double-click **`Stop Server.command`**.

> Installs to your Desktop by default. To put it elsewhere, drag the folder wherever you like after,
> or run it with a path: `./setup-server.command /your/folder`. (Change the player folder by editing
> `CLIENT_DIR` at the top of `setup-client.command`.)

## 3. Join as a player (each friend does this)

1. Double-click **`setup-client.command`** (needs the Minecraft Launcher installed & run once — **quit the launcher first**).
2. Open the Minecraft Launcher → pick the **Modded** profile → **Play**.
3. **Multiplayer → Add Server →** the host's `mc-XXXXXX.play.minekube.net` address.

> **Blocked by macOS** ("unidentified developer")? Right-click the file → **Open** once, then it's trusted. (Files from `git clone` don't hit this.)

---

## 🔧 Change the mods

The demo ships **Cobblemon** (everyone) and **Sodium** (client only). Two lists control the mods —
remember **every player needs the same gameplay mods**:

- **`mods.txt`** — gameplay mods installed on **both** the server and every client (e.g. Cobblemon).
- **`mods-client.txt`** — **client-only** mods that do nothing on a server (Sodium, shaders, minimaps).

Change either list two ways:
- **Quick (drag-and-drop):** drop a Fabric **1.21.1** mod `.jar` into the `mods` folders —
  server `~/Desktop/ModdedServer/FabricModdedServer/mods`, client `~/Desktop/ModdedClient/mods`.
- **Reproducible:** paste a mod's Modrinth link on its own line in the right list
  (Modrinth → Versions → right-click the 1.21.1 Fabric file → Copy Link), then re-run setup.
  Remove one by deleting its line and its `.jar`.

**Fabric API** and **FabricProxy-Lite** are installed automatically — Fabric API is required by most
mods, and FabricProxy-Lite is what lets the server accept players coming through the proxy. Leave both out of the lists.

Popular add-ons to try (must be built for MC 1.21.1): Simple Voice Chat, Cobbreeding, Mega Showdown, Radical Cobblemon Trainers.

## 🧪 Make a different server to experiment

Double-click **`Fabric Installer.command`** (in this folder) — it opens the Fabric installer's window
(downloading the installer the first time). Choose the **Server** (or **Client**) tab, pick any Minecraft
version, and **Install**. Handy for trying other versions or mod sets; the one-click `setup-server.command`
doesn't need it.

> **Why the wrapper instead of double-clicking the `.jar`?** macOS can't double-click a `.jar` with a
> JDK-only Java install — it looks for Java at a dead applet-plugin path and errors
> *"…JavaAppletPlugin.plugin…: No such file or directory"*. The wrapper (and the manual steps) just run
> `java -jar fabric-installer.jar`, which uses your installed JDK. You can run that in Terminal yourself too.

---

<details>
<summary><b>Manual setup — build it by hand (no scripts)</b></summary>

The exact same result the scripts produce. Uses the clickable installers where possible; a few steps
need **Terminal.app** (open it and `cd` into your folder).

**A. Java 21** — [download the macOS installer](https://adoptium.net/temurin/releases/?version=21) (`.pkg`), double-click, install.

**B. The Fabric server**
1. Open the **Fabric installer** — double-click **`Fabric Installer.command`**, or in Terminal run `java -jar ~/Downloads/fabric-installer-1.1.1.jar` (double-clicking the raw `.jar` fails on macOS; see the note under "Make a different server" above).
2. In the window: **Server** tab → Minecraft **1.21.1**, Loader **0.19.3** → pick a new folder (e.g. `~/Desktop/ModdedServer/FabricModdedServer`) → **Install Server**. Creates `fabric-server-launch.jar`.
3. Put the **1.21.1 `server.jar`** in that folder: [direct download](https://piston-data.mojang.com/v1/objects/59353fb40c36d304f2035d51e7d6e6baa98dc05c/server.jar) (the official page only has the newest version).

**C. Mods** → into a `mods` subfolder. From Modrinth, grab each mod's **1.21.1 Fabric** file:
- [Fabric API](https://modrinth.com/mod/fabric-api) — needed by most mods
- [FabricProxy-Lite](https://modrinth.com/mod/fabricproxy-lite) — lets the server accept players coming through the proxy
- [Cobblemon](https://modrinth.com/mod/cobblemon) — the demo mod (swap for anything)

**D. First run + EULA** — in Terminal, inside the server folder:
```
java -jar fabric-server-launch.jar nogui
```
It stops and asks for the EULA → open `eula.txt`, set `eula=true`.

**E. Point the server at the proxy**
- In `server.properties`: `server-port=25566` and **`online-mode=false`** ← the key fix (the proxy does the login).
- Create `config/FabricProxy-Lite.toml`:
  ```toml
  hackOnlineMode = false
  hackEarlySend = false
  hackMessageChain = false
  secret = "PICK-A-RANDOM-STRING"
  ```

**F. The Gate proxy** — *this is the fix: Gate, not Velocity*
1. Download [**Gate**](https://github.com/minekube/gate/releases/latest) (`gate_..._darwin_arm64`) into a `GateProxy` folder.
2. In Terminal: `chmod +x gate && xattr -dr com.apple.quarantine gate`
3. Create `GateProxy/config.yml` (same secret as step E):
   ```yaml
   config:
     bind: 0.0.0.0:25565
     onlineMode: true
     forwarding: { mode: velocity, velocitySecret: "PICK-A-RANDOM-STRING" }
     servers: { fabric: 127.0.0.1:25566 }
     try: [fabric]
     lite: { enabled: false }
   connect:
     enabled: true
     name: pick-a-unique-name        # → pick-a-unique-name.play.minekube.net
   ```

**G. Run it** — two Terminal windows:
- Server (in the server folder): `java -jar fabric-server-launch.jar nogui`
- Proxy (in `GateProxy`): `./gate` → it prints your public address.

Test at `localhost:25565`, then share `your-name.play.minekube.net`. Players still need the client mods (step C on their machine + a Fabric profile in their launcher).

</details>

<details>
<summary><b>Details — versions, how it works, lessons</b></summary>

### Pinned versions (verified July 2026)

| Component | Version |
|---|---|
| Minecraft | 1.21.1 |
| Fabric loader / installer | 0.19.3 / 1.1.1 |
| Fabric API | 0.116.13+1.21.1 |
| FabricProxy-Lite | 2.10.1 |
| Gate | 0.68.26 |
| Cobblemon (demo, both) | 1.7.3+1.21.1 |
| Sodium (demo, client-only) | 0.8.12+mc1.21.1 |

To move to another Minecraft version, update the URLs at the top of `setup-server.command` / `setup-client.command` and the links in `mods.txt`.

### How it's wired

```
Friend's client ── mc-XXXXXX.play.minekube.net ──▶ Minekube edge (public)
                                                       │ outbound tunnel (no ports opened)
                                                       ▼
                                     Gate  0.0.0.0:25565  (Connect built in)
                                                       │ velocity modern forwarding
                                                       ▼
                                     Fabric  127.0.0.1:25566  (offline-mode)
```

The public address points at Minekube's shared edge, never your home IP. Gate authenticates players and
forwards a trusted profile, so the backend runs `online-mode=false` and the shared secret in
`GateProxy/config.yml` must match `FabricProxy-Lite.toml` (setup generates one value for both).

### Repo layout

```
setup-server.command   # host installer (server + proxy)
setup-client.command   # player installer (Minecraft Launcher + mods)
mods.txt               # gameplay mods (edit to change what's installed)
scripts/               # source of the Start/Stop launchers (setup copies these)
templates/             # Gate + FabricProxy-Lite config templates (setup fills in secret + endpoint)
```

Downloaded jars, worlds, logs, and the generated `config.yml`/secret are git-ignored — the repo never
contains secrets or Mojang's `server.jar` (which must not be redistributed).

### Notes / lessons

- **Use Gate, not Velocity.** Velocity + the `connect` plugin kicks Fabric-tunneled players at the
  handshake (`multiplayer.disconnect.incompatible`) → they land in Minekube's "Browser Hub". Gate's
  native Connect support fixes it.
- **Backend must be `online-mode=false`** behind modern forwarding (the proxy does the auth).
- **All players need the same Minecraft version + mods**, or they're rejected as incompatible.
- **Known quirk:** connecting from the *same machine* as the server has dropped the session ~every 60s
  (traffic hairpins out to the edge and back). `localhost:25565` and genuinely remote players are fine.

</details>
