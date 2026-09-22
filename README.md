# OlympusMute

A lightweight, client-side **World of Warcraft: Classic/Forever** addon for filtering unwanted players based on their guild.

OlympusMute automatically detects players belonging to configured guilds and can hide their chat messages, track them for filtering, and automatically decline guild or group invitations from matching players.

Originally designed around the **Olympus** guild name, OlympusMute now supports **multiple customizable guild-name filters** that can be added and managed directly in-game.

---

## ✨ Features

- 🔇 **Chat Filtering**
  - Hides chat messages from players belonging to configured guilds.
  - Works with saved guild-name patterns rather than a single hard-coded guild.

- 🛡️ **Automatic Invite Handling**
  - Automatically declines guild invitations from matching players.
  - Optionally declines group invitations from matching players.

- 🔍 **Automatic Background Scanning**
  - Periodically performs `/who` searches in the background.
  - Rotates through guild filters and level ranges to find more matching players.
  - Designed to avoid unnecessarily hammering the WoW `/who` system.

- 💾 **Persistent Guild Filters**
  - Add as many guild-name filters as you need.
  - Your configured filters persist between sessions.
  - Example:
    - `Olympus`
    - `Olympus Canada`
    - `Olympus Gaming`
    - `Olympus PvP`

- 🧹 **Temporary Player Cache**
  - Learned player names and GUIDs are cleared when you log in.
  - Prevents the SavedVariables database from growing indefinitely.
  - Your configured guild filters remain intact.

- ⚙️ **In-Game Configuration**
  - Manage guild filters without manually editing Lua files.
  - Toggle filtering and invite behavior directly from the addon options.

---

## 📋 Commands

| Command | Description |
|--------|-------------|
| `/omute` | Display current status |
| `/omute config` | Open the configuration panel |
| `/omute on` | Enable chat filtering |
| `/omute off` | Disable chat filtering |
| `/omute guilds` | List saved guild filters |
| `/omute addguild <name>` | Add a guild-name filter |
| `/omute removeguild <name>` | Remove a guild-name filter |
| `/omute scan` | Run the next background `/who` scan manually |
| `/omute list` | List currently muted players |
| `/omute add <name>` | Manually add a player |
| `/omute remove <name>` | Remove a player from the mute list |
| `/omute clear` | Clear the current player cache |
| `/omute check <name>` | Check whether a player is currently muted |
| `/omute debug` | Toggle debug output |

---

## 🎯 Guild Filters

Guild filters are matched against guild names, so you don't need to enter every possible guild name individually.

For example, adding:

```text
Olympus

Created for personal World of Warcraft use.
Originally built around filtering players associated with Olympus, then expanded into a configurable guild-filtering addon.
