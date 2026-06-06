<!-- Project Summary (~150 chars, paste into the separate "Summary" field, NOT the description):
Turn your own buffs and debuffs into sound, speech, or on-screen flashes — proc alerts, cooldown windows, and debuff warnings.
-->

# AuraCue

**Turn your own buffs and debuffs into a sound, a spoken name, and/or an on-screen flash.**

*See the demo video and screenshots in the gallery above.*

AuraCue watches the auras *you* choose and fires a cue when each one is
**gained** or **lost** — handy for proc alerts, cooldown windows, and debuff
warnings. Pick any combination of:

- **Sound** — a distinct tone on the audio channel you pick (separate sounds
  for gained and lost), including matched open/close pairs where the gained
  tone rises and the lost one falls.
- **Speech** — the aura's name spoken aloud (text-to-speech). Set your own
  phrase — a general "{name} gained" format, or a per-aura override that can
  also use {name}: "{name} activated", or a name-free "Damage now" for Bloodlust.
- **On-screen flash** — center text and/or a screen-edge glow, with separate
  colors for gained vs lost.

Buffs and debuffs each get their own window, and every watched aura has an
**Edit** menu (or right-click) for its options — when to fire (everywhere, only
in combat, only in instances, or only in the open world), spoken text,
buff/debuff treatment, and combining.

## Built for Midnight's restrictions

Midnight (12.0) hides combat data from addons behind "secret values" in raids,
Mythic+, delves, and PvP. AuraCue works *with* that: it only tracks your own
auras and casts, tracks cast abilities from the cast event so their cues fire
in instances, and surfaces instanced debuffs through the game's private-aura
sound. Nothing it does is combat-locked.

**⚠️ Not every ability is trackable in combat.** Inside raids, Mythic+, delves,
and PvP the game hides auras addons aren't allowed to read. AuraCue still cues
the buffs *you* cast and plays a sound for debuffs that land on you — but an aura
that simply appears on you **without a cast you made** (a proc, or a buff someone
else puts on you) can't be tracked in that combat and will only cue out in the
open world. Out of instances, everything works.

## No spell-ID hunting

Your class's abilities are **pre-loaded from your spellbook** the moment you log
in, so the picker is useful right away — and the catalog keeps growing as you
play, adding every aura it sees on you plus every ability you cast (it's
account-wide, so each character fills in its class). Pick from grouped menus (by
class, mounts, dungeon, boss, or your own custom groups), filter and search to
thin a big list, and hide the clutter you don't want. There's a built-in Wowhead
search link if you ever do need an ID. Castable abilities are included too (even
ones with no aura of their own — they cue when *you* cast them), which is why
that page is called **Buffs/Skills**.

**No hard-coded ability list.** There's no built-in whitelist or blacklist of
spells — AuraCue learns purely from what it sees you cast and what lands on
you. That's by design: any aura works once it's been seen a single time,
including brand-new or reworked abilities from a patch, with nothing on the
addon's side to update. It never hides anything on its own either — **any hiding
is your choice** (and always reversible).

## More

- **Combine variants** — make a base spell and its proc version (different
  spell IDs) fire one alert, by name or by hand.
- **Manage Auras page** — bulk-edit your whole catalog: filter, group, hide,
  remove, or edit an entry's stored details.
- **Per character & spec** profiles, with export/import of profiles and the
  catalog — or copy a profile straight from another character on your account.

## Getting started

1. Open options with **/cue**.
2. Open **Buffs/Skills** or **Debuffs** in the settings list and add an aura
   from the picker (or by spell ID).
3. Set its sound / speech / flash and a When condition to taste.
4. **/cue test** to preview.
