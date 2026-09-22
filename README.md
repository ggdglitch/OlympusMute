# OlympusMute

A lightweight, client-side **World of Warcraft: Classic/Forever** addon for filtering players based on their guild.

OlympusMute can hide chat from learned players belonging to configured guilds and automatically decline guild or group invitations from matching players.

## ✨ Features

- 🔇 Chat filtering for learned guild members
- 🎯 Multiple saved guild-name filters
- 🛡️ Optional automatic guild and group invite handling
- 🔍 Manual `/who` scanning
- 🧹 Learned player data is cleared on login
- 💾 Guild filters and settings persist between sessions
- ⚙️ In-game configuration
- 🐛 Debug mode

## 🎯 Guild Filters

Guild filters use partial-name matching.

For example:

```text
Olympus
```

can match:

```text
Olympus
Olympus Canada
Olympus Gaming
Olympus PvP
Olympus USA
The Olympus
```

Manage filters in-game:

```text
/omute addguild Olympus Canada
/omute removeguild Olympus Canada
/omute guilds
```

Guild filters are saved between sessions.

## 🔍 Scanning

The learned player list is cleared when you log in to keep the database small.

Players can be learned through:

- Targeting
- Mouseover
- Nameplates
- Group members
- `/who` results

You can manually run the next guild scan with:

```text
/omute scan
```

or use the **Scan /who guilds** button in the addon options.

> `/who` searches must be initiated by the player due to WoW's protected API restrictions.

## 📋 Commands

| Command | Description |
|---|---|
| `/omute` | Show addon status |
| `/omute config` | Open addon options |
| `/omute on` | Enable filtering |
| `/omute off` | Disable filtering |
| `/omute guilds` | List saved guild filters |
| `/omute addguild <name>` | Add a guild filter |
| `/omute removeguild <name>` | Remove a guild filter |
| `/omute scan` | Run the next `/who` scan |
| `/omute list` | List currently learned players |
| `/omute add <name>` | Manually mute a player |
| `/omute remove <name>` | Remove a player |
| `/omute check <name>` | Check a player |
| `/omute clear` | Clear the learned player cache |
| `/omute debug` | Toggle debug output |

## 💾 SavedVariables

OlympusMute uses:

```text
OlympusMuteDB
```

Persistent settings include:

- Enabled/disabled state
- Guild-name filters
- Invite settings
- Debug settings

Learned player data is intentionally cleared on login.

## 📦 Installation

Place the `OlympusMute` folder in your WoW AddOns directory:

```text
World of Warcraft/
└── _classic_era_/
    └── Interface/
        └── AddOns/
            └── OlympusMute/
                ├── OlympusMute.toc
                └── OlympusMute.lua
```

Enable **OlympusMute** from the AddOns menu, then use:

```text
/omute config
```

to configure it.

## 🐛 Debugging

Enable debug output with:

```text
/omute debug
```

Run the command again to disable it.

## ⚠️ Notes

OlympusMute is entirely client-side.

It does not add players to your WoW ignore list, notify other players, or modify the server.

## 📜 Version

**1.2.0**

### What's New in 1.2.0

- Added smarter /who scanning with level-range tracking
- Added automatic cleanup for players who leave matching guilds
- Migrated existing guild filters to the new keyword system
- Kept learned player data temporary and cleared on login
- Preserved user-initiated /who scanning to avoid protected-action errors
- Added support for both new and legacy guild filter commands

**1.1.1**

### What's New in 1.1.1

- Fixed protected `/who` calls causing interface-action errors
- `/who` scanning is now user-initiated
- Guild filters persist between sessions
- Learned player data is cleared on login
- Existing chat filtering and invite handling remain intact

## ❤️ Credits

Created for personal World of Warcraft use.

Originally built around filtering players associated with **Olympus**, then expanded into a configurable guild-filtering addon.
OlympusMute
