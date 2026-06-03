<!-- Project Summary (~150 chars, paste into the separate "Summary" field, NOT the description):
Turn your own buffs and debuffs into sound, speech, or on-screen flashes — proc alerts, missing-buff reminders, and debuff warnings.
-->

# AuraCue

**Turn your own buffs and debuffs into a sound, a spoken name, and/or an on-screen flash.**

AuraCue watches the auras *you* choose and fires a cue when each one is
**gained** or **fades** — handy for proc alerts, missing-buff reminders, and
debuff warnings. Pick whichever cue you want:

- **Sound** — a distinct tone on the audio channel you pick.
- **Speech** — the aura's name spoken aloud (text-to-speech).
- **On-screen flash** — center text and/or a screen-edge glow, with separate
  colors for gained vs faded.
- Or run several at once.

## Works inside raids, Mythic+, and PvP

Midnight's addon restrictions hide enemy combat data, which is why broad
trackers went dark this expansion. AuraCue is built around that: it reads
only **your own auras** — which stay readable in combat — so your cues keep
firing where it matters. Nothing it does is combat-locked.

## Getting started

1. Open options with **/cue** (or the Addon Compartment button).
2. Add an aura by spell ID: **/cue add 2825** (that's Bloodlust). Find IDs
   on Wowhead — they're in the page URL.
3. Set the flash color/size/duration and the audio channel to taste.
4. **/cue test** to preview, **/cue unlock** to drag the overlay where you
   want it.

## On the roadmap

- Point-and-click watched-aura editor (per-aura sound and applied/faded triggers)
- Distinct bundled cue sounds
- Cast-bar / interrupt-window cues
- Boss-debuff (private aura) cues surfaced as a visual flash

Built small and focused, like the rest of the family: OutOfRange,
DontRelease, MinimapIconBar, CombatReticle.
