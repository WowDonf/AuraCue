# Changelog

## v0.3.1

- Fix a Lua error on login ("attempt to index global 'CueSenseDB'") caused
  by the new spell-picker building its menu before saved variables loaded.

## v0.3.0

- **Pick a spell to watch from a list.** "Add a spell" is now a dropdown of
  your known spells, each shown with its icon and name — no need to look up
  a spell ID. Already-watched spells are marked. Adding by raw spell ID is
  still available below for auras that aren't in your spellbook (trinket
  procs, set bonuses, debuffs applied by others).
- **Lock the overlay from the screen.** Moving the overlay now shows a
  "Done — lock here" button right under it, so you can finish positioning
  without typing `/cue lock`.

## v0.2.0

- **In-panel cue editor.** The options panel now lists every watched aura
  with per-aura controls: **gained** / **faded** / **visual** toggles, a
  sound dropdown with a preview button, and a remove button. No more
  managing the list from chat (the `/cue` commands still work).
- **Add by spell ID, in the panel.** Type an ID and click Add; unknown or
  non-numeric IDs are rejected with an inline message, and the resolved
  spell name is confirmed.
- The watched list and counts stay in sync whether you edit from the panel
  or the slash commands.

## v0.1.0

Initial release.

- **Player aura cues.** Watch any of your own buffs or debuffs by spell ID
  and get a cue when it is **gained** or **fades** — a sound, an on-screen
  flash, or both. The two-channel design is the point: deaf / hard-of-hearing
  players read the flash, blind / low-vision players hear the sound.
- **On-screen flash overlay.** Center-screen text cue with configurable
  color, size (0.5x – 3.0x), and on-screen time (0.5 – 8.0s). Movable and
  lockable; position is saved account-wide.
- **Audio routing.** Cue sounds play through a configurable channel
  (Master / SFX / Music / Ambience / Dialog) so cue volume can be balanced
  against game audio. Ships with six built-in tones; custom bundled sounds
  are planned.
- **Built for Midnight (12.x) restrictions.** CueSense only reads the
  player's own auras, which Blizzard keeps non-secret even in combat, and
  routes every value through a secret-value guard — so it works inside raid
  encounters, Mythic+, and PvP where addons can't read enemy combat data.
- **Slash commands** (`/cue`): `add <spellID>`, `remove <spellID>`, `list`,
  `test`, `toggle`, `unlock` / `lock`, `reset`, `status`.
- **Addon Compartment** button: left-click for options, right-click to
  toggle on/off.
