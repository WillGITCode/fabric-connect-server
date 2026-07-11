# Cobblemon Server (Fabric + Gate + Minekube Connect)

A one-command setup for a **modded Minecraft 1.21.1 Cobblemon server** that friends on
other networks can join **without port-forwarding your router or exposing your home IP**.

It uses a [Gate](https://gate.minekube.com) proxy with [Minekube Connect](https://connect.minekube.com)
built in: your server dials *out* to Minekube's edge, and players join a public
`something.play.minekube.net` address that resolves to Minekube — never to you.

> **Why Gate and not Velocity?** The obvious Velocity + `connect` plugin route does **not**
> work with a Fabric backend — tunneled players get kicked at the handshake
> (`multiplayer.disconnect.incompatible`) and land in Minekube's "Browser Hub". Gate's
> native Connect support fixes it. See [NOTES](#notes--lessons-learned).

---

## Requirements

- **macOS** (Apple Silicon or Intel)
- **Java 21 (JDK)** — required for Minecraft 1.21.1. Check with `java -version` (must say `21`).
  Install from [Adoptium](https://adoptium.net/temurin/releases/?version=21) if you don't have it.

## Quick start

```sh
git clone https://github.com/WillGITCode/cobblemon-server.git
cd cobblemon-server
./setup-cobblemon-server.command          # or double-click it in Finder
```

Setup downloads everything (~200 MB) and installs a ready-to-run server to
`~/CobblemonServer` by default (pass a path to change it). Then:

1. Open `~/CobblemonServer` in Finder.
2. Double-click **`Start Cobblemon Server.command`**.
3. Wait for `Done` in the window. Your public address is printed there and in `GateProxy/config.yml`.
4. Friends join that `*.play.minekube.net` address; you can also join at `localhost:25565`.

**To stop:** close the Start window (or type `stop` + Return). `Stop Cobblemon Server.command`
is a force-stop safety net.

> First double-click may hit macOS Gatekeeper ("unidentified developer"). Files obtained via
> `git clone` are **not** quarantined, so this usually just works; if blocked, right-click → **Open** once.

## Joining as a player (client setup)

A fully-modded server means **every player needs matching client mods** — otherwise they can't
join. `setup-cobblemon-client.command` prepares the **official Minecraft Launcher** to join:

```sh
./setup-cobblemon-client.command          # or double-click it
```

Requirements: **Java 21** and the **Minecraft Launcher installed + run once** (logged in).
It will:
- install Fabric `0.19.3` for `1.21.1` into the launcher,
- download Fabric API + Cobblemon into a **dedicated game folder** (`~/CobblemonClient`) so it
  doesn't touch your other worlds/mods,
- add a **"Cobblemon"** launcher profile pointed at that folder (existing profiles are preserved;
  the file is backed up first).

> **Quit the Minecraft Launcher before running it** — the launcher rewrites its profiles on exit
> and would drop the new one. The script reminds you and waits.

Then: open the launcher → pick the **Cobblemon** profile → Play → Multiplayer → add the host's
`cobblemon-XXXX.play.minekube.net` address.

## What gets installed

```
~/CobblemonServer/
├── Start Cobblemon Server.command
├── Stop Cobblemon Server.command
├── FabricModdedServer/     # Fabric 1.21.1 server + mods + world
│   ├── mods/               # Cobblemon, Fabric API, FabricProxy-Lite
│   └── config/FabricProxy-Lite.toml
└── GateProxy/
    ├── gate                # Gate binary
    └── config.yml          # proxy + Connect endpoint (holds your secret)
```

## Pinned versions (verified July 2026)

| Component | Version |
|---|---|
| Minecraft | 1.21.1 |
| Fabric loader / installer | 0.19.3 / 1.1.1 |
| Cobblemon | 1.7.3+1.21.1 |
| Fabric API | 0.116.13+1.21.1 |
| FabricProxy-Lite | 2.10.1 |
| Gate | 0.68.26 |

To bump versions, edit the URLs/versions at the top of `setup-cobblemon-server.command`.

## How it's wired

```
Friend's client ── cobblemon-XXXX.play.minekube.net ──▶ Minekube edge (public)
                                                            │ outbound tunnel
                                                            ▼
                                          Gate  0.0.0.0:25565  (Connect built in)
                                                            │ velocity modern forwarding
                                                            ▼
                                          Fabric  127.0.0.1:25566  (offline-mode)
```

- Gate authenticates players and forwards a trusted profile, so the **backend runs offline-mode**.
- The **shared secret** must match between `GateProxy/config.yml` (`velocitySecret`) and
  `FabricModdedServer/config/FabricProxy-Lite.toml` (`secret`). Setup generates a fresh one for both.
- The **endpoint name** (`cobblemon-XXXX`) is random per install so it won't collide on the
  Connect network. Change it in `GateProxy/config.yml` if you like — the Start script reads it automatically.

## Repo layout

```
setup-cobblemon-server.command   # host installer (server + proxy)
setup-cobblemon-client.command   # player installer (Minecraft Launcher: Fabric + client mods)
scripts/                         # source of the Start/Stop launchers (setup copies these)
templates/                       # config templates (setup fills in secret + endpoint)
```

Downloaded jars, world data, logs, and the generated `config.yml`/secret are **git-ignored** —
the repo stays small and never contains secrets or Mojang's `server.jar` (which must not be redistributed).

## Notes / lessons learned

- **Backend must be `online-mode=false`** behind modern-forwarding. `online-mode=true` +
  FabricProxy-Lite `hackOnlineMode=true` *appears* to work for direct connections but breaks over Connect.
- **Everything must be the same Minecraft version.** Gate accepts many client versions; the single
  Fabric backend only speaks 1.21.1 and rejects anything else as incompatible.
- **"Hub"** = Minekube's Browser Hub fallback, shown when your endpoint is offline or a player is
  disconnected from your backend. Seeing it means the player didn't stay on your server.
- **Known open issue:** connecting from the *same machine/network* as the server (traffic hairpins
  out to the edge and back) has dropped the session periodically in testing; a genuinely remote
  client is the real test. `localhost:25565` (no tunnel) is always stable.
