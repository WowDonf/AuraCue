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

- **Visual cue:** show/hide the flash, color, size, on-screen time, and
  position.
- **Audio cue:** the channel cue sounds route through.
- **Watched auras:** add by spell ID and edit each aura's sound, its
  gained/faded triggers, and its visual flash right in the panel. The
  `/cue` commands still work too.

## Roadmap

- Distinct bundled cue sounds
- Player cast-bar / interrupt-window cues
- Private-aura applied cues (boss debuffs surfaced as a visual flash)
- Resource / health threshold cues
