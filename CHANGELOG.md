# Changelog

## v0.7.1

- Sharper addon icon (antialiased PNG).

## v0.7.0

- **Distinct bundled cue sounds.** Ships eight short, easy-to-tell-apart
  tones — Rise, Fall, Ping, Beep, Double, Triple, Chirp, Thud — so you can
  give different auras different sounds and recognize them by ear. Replaces
  the previous built-in game sounds.
- **Addon icon.** CueSense now has its own icon in the addon list and
  compartment button.

## v0.6.1

- Debuffs taken in Delves (and other scenario-based content) now file under
  the instance's name like dungeon debuffs do, instead of landing under
  "Other". Tracking already worked everywhere; this fixes the auto-grouping.

## v0.6.0

- **Buffs and debuffs now have separate tabs.** The watched list shows one
  kind at a time — switch with the Buffs / Debuffs tabs (each shows its
  count) instead of scrolling one combined list.
- **Debuffs remember where they came from.** When an aura is first seen,
  CueSense records the dungeon, and debuffs file themselves under that
  dungeon's heading automatically. The source mob is captured too and shown
  when you hover a row — though the game hides it inside many instances, so
  it can read "unknown" there.
- Each row still has a Group field to re-file an aura under your own heading.

## v0.5.0

- **Audio is fully optional.** New "Play sound cues" master switch, and each
  aura can be set to "None (silent)" for a visual-only cue. Visual was
  already optional per-aura; now sound matches.
- **Separate buff / debuff tracking.** "Track buffs" and "Track debuffs"
  toggles let you run one without the other. Each aura is tagged as a buff
  or debuff automatically.
- **Categories.** The watched list is grouped under headings — Buffs and
  Debuffs by default — and every row has a Group field you can type into
  (e.g. a dungeon name) to file that aura under your own heading. Makes a
  long list much easier to scan and manage.

## v0.4.0

- **The "add" list now only shows auras that actually track.** It's built
  from auras seen on you (filling in as they appear), instead of your whole
  spellbook — so abilities that put no aura on you (interrupts, direct
  damage, target debuffs) no longer clutter the list or get added by
  mistake. Adding by spell ID is still there for auras you haven't had yet.
  New `/cue forget` clears the remembered-aura list.
- **The move overlay now looks like a window.** While repositioning it
  shows a bordered box with an "X" in the corner to close/lock it, matching
  the OutOfRange movable frame.
- **The add list scrolls** instead of running off the bottom of the screen
  at 1920x1080 and similar resolutions.

## v0.3.2

- Flag auras that the client reports as hidden in instanced content
  ("may be hidden in instances") in the spell picker and when adding by
  ID, so it's clear up front which cues may not fire during raids, Mythic+,
  or PvP. Your own auras stay readable, so this mostly affects auras added
  by ID (enemy/boss debuffs, other players' buffs).

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
