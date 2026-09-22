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
A lightweight, client-side World of Warcraft: Classic/Forever addon for filtering unwanted players based on their guild.
OlympusMute automatically detects players belonging to configured guilds and can hide their chat messages, track them for filtering, and automatically decline guild or group invitations from matching players.
Originally designed around the Olympus guild name, OlympusMute now supports multiple customizable guild-name filters that can be added and managed directly in-game.
✨ Features
- 🔇 Chat Filtering
  - Hides chat messages from players belonging to configured guilds.
  - Supports multiple saved guild-name filters.
- 🛡️ Automatic Invite Handling
  - Automatically declines guild invitations from matching players.
  - Optionally declines group invitations from matching players.
- 🔍 Automatic Background Scanning
  - Periodically performs /who searches in the background.
  - Rotates through guild filters and level ranges.
  - Helps discover matching players as they come online.
- 💾 Persistent Guild Filters
  - Add and remove guild filters directly in-game.
  - Filters persist between sessions.
  - Supports partial guild-name matching.
- 🧹 Temporary Player Cache
  - Learned player names and GUIDs are cleared when you log in.
  - Prevents the SavedVariables database from growing indefinitely.
  - Your configured guild filters remain saved.
- ⚙️ In-Game Configuration
  - Manage guild filters without manually editing Lua files.
  - Configure filtering and invite behavior from the addon options.
📋 Commands
Command	Description
/omute	Display current status
/omute config	Open the configuration panel
/omute on	Enable filtering
/omute off	Disable filtering
/omute guilds	List saved guild filters
/omute addguild <name>	Add a guild-name filter
/omute removeguild <name>	Remove a guild-name filter
/omute scan	Run a /who scan manually
/omute list	List currently muted players
/omute add <name>	Manually add a player
/omute remove <name>	Remove a player
/omute clear	Clear the current player cache
/omute check <name>	Check whether a player is muted
/omute debug	Toggle debug output


🎯 Guild Filters
Guild filters use partial-name matching.
For example, adding:
Olympus
can match guilds such as:
Olympus
Olympus Canada
Olympus Gaming
The Olympus
Olympus PvP
You can also add more specific filters when needed:
Olympus Canada
Olympus Gaming
Manage filters directly in-game with:
/omute addguild Olympus Canada
or:
/omute removeguild Olympus Canada
🔄 Background Scanning
When you log in, OlympusMute clears its temporary list of previously discovered players.
Your saved guild filters are not cleared.
After login, the addon automatically begins cycling through /who searches using your saved guild filters and level ranges.
Matching players are added to the temporary player cache and can then be filtered automatically.
This keeps the player database small while allowing OlympusMute to rediscover matching players as they come online.
💾 SavedVariables
OlympusMute uses:
OlympusMuteDB
The database stores persistent configuration such as:
- Enabled/disabled state
- Guild-name filters
- Invite settings
- Other addon preferences
The learned player cache is intentionally cleared on login to prevent the database from growing indefinitely.
📦 Installation
1. Download or clone the repository.
2. Place the OlympusMute folder inside your WoW AddOns directory.
3. Make sure the folder contains:
OlympusMute/
├── OlympusMute.toc
└── OlympusMute.lua
4. Launch World of Warcraft.
5. Enable OlympusMute from the AddOns menu.
6. Open the configuration panel with:
/omute config
🧪 Debugging
To enable debug output:
/omute debug
This will display additional information about background scanning and addon activity.
Run the command again to disable debugging.
⚠️ Notes
OlympusMute is a client-side addon. It does not modify the WoW server or affect other players.
Filtering and invite handling occur locally on your client.
Background /who scanning is performed periodically to avoid excessive requests.
📜 Version
1.1.0
What's New in 1.1.0
- Added customizable guild-name filters
- Added in-game guild filter management
- Added automatic background /who scanning
- Added rotating level-range searches
- Player cache is cleared on login
- Guild filters persist between sessions
- Added additional configuration and debugging commands
- Updated addon configuration and TOC
❤️ Credits
Created for personal World of Warcraft use.
Originally built around filtering players associated with Olympus, then expanded into a configurable guild-filtering addon.
