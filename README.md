# AuraCue

A personal aura-alert addon for World of Warcraft (Midnight, 12.x). AuraCue
turns your own buffs and debuffs into a **sound**, a **spoken name**, and/or
an **on-screen flash** — for proc alerts, missing-buff reminders, cooldown
windows, and debuff warnings.

Each watched aura can cue when it's **gained**, when it **fades**, or both:

- **Sound** — a distinct bundled tone, on the audio channel you pick. Separate
  sounds for gained and faded (or "None" for silent).
- **Speech** — the aura's name spoken aloud (text-to-speech), with voice /
  rate / volume controls.
- **On-screen flash** — center text and/or a screen-edge glow, with separate
  colors for gained vs faded, and adjustable size, on-screen time, and edge
  thickness / intensity.

Buffs and debuffs each get their own on-screen window (size, colors, position,
duration), and each aura can be limited with a **When** condition — fire
everywhere, only in combat, only in instances, or only in the open world.

## Working in instances

Midnight (patch 12.0) hides combat data from addons behind "secret values"
during raids, Mythic+, delves, and PvP — which is why broad trackers lost much
of their coverage. AuraCue is built around that wall instead of fighting it:

- It only ever tracks **your own** auras and casts, which stay available.
- Buffs you **cast** are tracked from the cast event (non-secret in instances),
  so their cues fire there even when the aura itself can't be read.
- Debuffs that land on you in instances are surfaced through the game's
  **private-aura applied sound**, so a debuff's Gained sound still plays.
- Every value it reads is guarded, so it never errors on a masked one.

## The aura picker

You build your watch list from a catalog AuraCue fills in as you play — every
aura it sees on you, plus every ability you cast. You never have to hunt for
spell IDs (though you still can add one by ID).

- **Grouped submenus.** Buffs group under **your class** (e.g. abilities your
  Shaman casts → "Shaman"), **Mounts**, **From you / your pet**, and **World &
  other**. Debuffs group under **Boss**, the **dungeon** they came from, or
  **Other**. You can also file any aura under a **custom group** of your own.
- **Filters** (the "Show" dropdown) combine to thin a big list: only abilities
  you know, only boss auras, only role-relevant auras, only permanent or only
  timed, hide mounts, only ungrouped, and so on. Already-tracked auras are
  always left out.
- **Search / hide.** Click the search box to see your auras; the ✕ hides an
  aura you don't want (account-wide), the note icon files it into a group, and
  with "Show hidden auras" on you can restore one with the **+**.
- **Find an ID → Search Wowhead.** Type a spell name to get a copyable Wowhead
  search link (addons can't browse the web), where the ID is in the URL.

## Combining variants into one alert

Some abilities have more than one form with different spell IDs — e.g. a base
spell and its talented proc version. AuraCue can treat them as one cue:

- **Combine auras with the same name** (a Global Setting) makes every
  same-named aura drive a single alert and merges duplicate rows.
- Or **right-click a watched row** to combine just that one by name, or to add
  specific extra spell IDs by hand.

## Managing the catalog

The **Manage Auras** page is a full edit view of your account-wide catalog:
search it, set a custom group, hide or show entries, or remove them — one at a
time or in bulk by ticking rows. Removing an aura just forgets it until you see
it again.

## Profiles & sharing

Settings are saved **per character and specialization**, so each spec keeps its
own watch list and windows. The **Sharing** page exports the current spec's
profile, or the whole aura catalog, to a copy-paste string — and imports one
back. It can also **copy a profile from another character/spec** on your
account directly (no string needed). The catalog is account-wide (shared across
all your characters).

## Usage

Open options with `/cue`.

| Command | Does |
| --- | --- |
| `/cue` | Open the options panel |
| `/cue add <id>` / `/cue remove <id>` | Watch / unwatch an aura by spell ID |
| `/cue list` | List watched auras |
| `/cue test` | Preview a cue |
| `/cue toggle` | Enable / disable |
| `/cue unlock` (`move`) / `/cue lock` | Move / lock the on-screen window |
| `/cue reset` | Reset window position |
| `/cue gather` | Catalog auras on nearby units (target, focus, party, …) |
| `/cue forget` | Clear the remembered-aura catalog |
| `/cue tts` | Diagnose text-to-speech |
| `/cue status` | Print current settings |

## Roadmap

- Player cast-bar / interrupt-window cues
- Resource / health threshold cues
