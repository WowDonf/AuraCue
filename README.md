# CueSense

An accessibility addon for World of Warcraft (Midnight, 12.x). CueSense
turns your own buffs and debuffs into a **sound**, an **on-screen flash**,
or **both** — an audio↔visual bridge so a player who can't perceive one
channel still gets the cue on the other.

- **Deaf / hard-of-hearing:** see a flash when a tracked aura is gained or
  fades.
- **Blind / low-vision:** hear a distinct cue routed through the audio
  channel you choose.

## Why it works inside instances

Midnight (patch 12.0) hides most combat data from addons behind "secret
values" during raid encounters, Mythic+, and PvP — which is why broad
hazard-tracking addons lost almost all their coverage. CueSense sidesteps
that wall on purpose: it only reads **your own auras**, which Blizzard
keeps readable even in combat, and guards every value it touches so it
never errors on a masked one. Sound playback and the on-screen overlay
aren't combat-restricted at all.

## Usage

Open options with `/cue`, or from the Addon Compartment button (left-click
for options, right-click to toggle on/off).

Watch an aura by its spell ID:

```
/cue add 2825      -- e.g. Bloodlust
/cue remove 2825
/cue list
```

Other commands:

| Command | Does |
| --- | --- |
| `/cue` | Open the options panel |
| `/cue test` | Preview a cue |
| `/cue toggle` | Enable / disable |
| `/cue unlock` / `/cue lock` | Move the on-screen overlay |
| `/cue reset` | Reset overlay position |
| `/cue status` | Print current settings |

Tip: look up spell IDs on Wowhead — the ID is in the page URL.

## Settings

- **Visual cue:** buffs and debuffs each have their own window — set show/
  hide, color, size, on-screen time, and position separately under each
  tab. Use "Test this window" to preview it.
- **Audio cue:** a master "Play sound cues" switch and the channel sounds
  route through. Any aura can be set to "None (silent)" for visual-only.
- **Buffs vs debuffs:** track buffs and debuffs independently, and manage
  each on its own page in the settings list (CueSense ▸ Buffs / Debuffs).
  Debuffs file themselves under the dungeon they were
  first seen in; hover a row to see its source mob (when the game exposes
  it). Type a Group name on any row to re-file it under your own heading.
- **Watched auras:** pick from a list of auras you've actually had (shown
  with icon and name) — so only auras that genuinely track are offered — or
  add by spell ID for an aura you haven't had yet. Each aura has its own
  gained/faded triggers, a separate sound for gained and for faded (or
  "None" for silent), and a visual toggle — all editable in the panel. The
  `/cue` commands still work too.
- **Moving the overlay:** `/cue unlock` (or the panel's "Move overlay"
  button) shows it as a bordered window with an "X" in the corner to lock
  it back down.

## Roadmap

- Player cast-bar / interrupt-window cues
- Private-aura applied cues (boss debuffs surfaced as a visual flash)
- Resource / health threshold cues
