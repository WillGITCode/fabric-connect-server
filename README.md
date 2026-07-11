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

1. Double-click **`setup-server.command`** — downloads everything (~200 MB, a few minutes) into a new `~/ModdedServer` folder.
2. Open `~/ModdedServer` and double-click **`Start Server.command`**.
3. Wait for the word **`Done`**. The window shows your address (e.g. `mc-ab12cd.play.minekube.net`) — share it with friends.
4. **Stop:** close that window, or double-click **`Stop Server.command`**.

## 3. Join as a player (each friend does this)

1. Double-click **`setup-client.command`** (needs the Minecraft Launcher installed & run once — **quit the launcher first**).
2. Open the Minecraft Launcher → pick the **Modded** profile → **Play**.
3. **Multiplayer → Add Server →** the host's `mc-XXXXXX.play.minekube.net` address.

> **Blocked by macOS** ("unidentified developer")? Right-click the file → **Open** once, then it's trusted. (Files from `git clone` don't hit this.)

---

## 🔧 Change the mods

The demo ships **Cobblemon**. To make it your own — remember **every player must have the same mods**:

- **Quick (drag-and-drop):** drop a Fabric **1.21.1** mod `.jar` into the `mods` folders —
  server `~/ModdedServer/FabricModdedServer/mods`, client `~/ModdedClient/mods`.
- **Reproducible:** edit **`mods.txt`** — paste a mod's Modrinth download link on its own line
  (Modrinth → mod page → Versions → right-click the 1.21.1 Fabric file → Copy Link), then re-run setup.
  Remove one by deleting its line and its `.jar`.
- Don't list **Fabric API** or **FabricProxy-Lite** — setup always installs those.

Popular Cobblemon add-ons to try (must be built for MC 1.21.1): Simple Voice Chat, Cobbreeding, Mega Showdown, Radical Cobblemon Trainers.

## 🧪 Make a different server to experiment

The **Fabric installer is itself a clickable app**: [download `fabric-installer.jar`](https://fabricmc.net/use/installer/),
double-click it, choose the **Server** (or **Client**) tab, pick any Minecraft version, and **Install**.
Handy for trying other versions or mod sets by hand. Our `setup-server.command` just automates the 1.21.1 case.

---

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
| Cobblemon (demo mod) | 1.7.3+1.21.1 |

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
