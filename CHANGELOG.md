# Changelog

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
