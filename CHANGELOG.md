# Changelog

## v0.25.1

- The settings carry-over from the old CueSense name now prints a
  confirmation when it runs. Note: because the game stores each addon's
  saved data under its folder name, carrying your old data over requires
  renaming the SavedVariables file `CueSense.lua` to `AuraCue.lua` once
  (with the game closed); after that, your first login imports it.

## v0.25.0

- **Renamed to AuraCue.** The addon is now a general-purpose personal
  aura-alert tool — turn your own buffs and debuffs into sound, speech, or
  on-screen flashes for proc alerts, missing-buff reminders, and debuff
  warnings. Your existing settings and aura catalog carry over automatically
  on first login. The `/cue` command still works (with `/auracue` as an
  alias).

## v0.24.0

- Sharing moved to its own page in the left-hand list, with separate
  Export and Import boxes (so a string you paste to import no longer
  collides with the one you exported).
- Renamed the main "General" section to "Global Settings", and each
  window's "<kind> window" section to "General Settings".
- The Gained and Faded flash-color buttons now sit side by side.

## v0.23.0

- Gained and faded flashes can now use different colors. Each window
  (Buffs / Debuffs) has separate "Gained flash color" and "Faded flash
  color" pickers; the screen-edge glow matches whichever fired. Existing
  setups get sensible faded defaults automatically.
- Fixed the Sharing box: the export string now lives in a scrollable box,
  so it stays inside its frame and the mouse wheel scrolls the text
  instead of spilling over the panel.

## v0.22.1

- Full audit of the addon's API usage against the current 12.x client.
  Moved the specialization queries to `C_SpecializationInfo` and the
  spell-known check to `C_SpellBook` (the old globals were deprecated),
  each with a fallback for older clients.
- Private-aura sounds now register only for file-based cues, which is the
  only form that API accepts (a sound-kit id was never valid there and was
  being silently dropped). All shipped cue sounds are file-based, so
  audible behavior is unchanged.

## v0.22.0

- Fixed spoken cues being silent. The text-to-speech call was using an
  older argument order; the current client dropped the `destination`
  argument, which shifted our volume into the wrong slot and effectively
  spoke at volume 0. Speech now uses the correct `(voice, text, rate,
  volume)` order and is audible.
- Note: on Windows, the client routes text-to-speech through the **Effects**
  audio channel, so keep Effects volume up if speech is too quiet.

## v0.21.4

- `/cue tts` now also reports your Accessibility text-to-speech volume, so you
  can tell at a glance whether speech is silent because that volume is 0
  (which the addon can't override).

## v0.21.3

- **Faded cues work again for cast buffs.** A read now detects when a
  cast-tracked buff drops — but only after a read has confirmed it was up, so
  there's still no instant-fade for buffs whose aura ID differs from the cast.

## v0.21.2

- **Fix watched buffs flashing then instantly fading.** Cast-tracked auras no
  longer rely on aura reads — a cast buff's aura ID often differs from the
  cast, so reading by it wrongly reported "gone." Gained now fires on each
  cast; faded uses the duration timer.
- Spoken cues use the queued local audio channel now; added `/cue tts` to
  test speech and report what the client supports.

## v0.21.1

- **Fix cues only firing once.** A cast-tracked aura could get stuck "on" if
  its faded wasn't detected, so it never re-triggered. Reads now clear it when
  the buff actually drops (with a short grace window after a cast so it isn't
  marked faded before it registers), so gaining it again cues correctly.

## v0.21.0

- **Shape the screen-edge flash.** New per-window sliders for edge **thickness**
  (how far the glow reaches inward) and **intensity** (how strong it is), so
  you can dial the vignette from a subtle rim to a heavy full-edge alert. Use
  "Test this window" to preview while adjusting.

## v0.20.2

- Fix the "trackable in instances" filter missing buffs you cast. It now
  remembers the spells you actually cast and flags those (the old check
  misjudged buffs whose aura ID differs from the cast spell). Cast a buff
  once after updating and it'll show under the filter.

## v0.20.1

- The screen-edge flash now uses the exact cue color (same as the text). It
  was previously tinting a red game texture, so the color came out wrong.

## v0.20.0

- **Screen-edge flash.** Optionally flash the screen edges in the cue's color
  when a watched aura changes — a high-visibility, peripheral-vision cue on
  top of the center text. Toggle it per buff / debuff window.

## v0.19.0

- **Per-cue conditions.** Each watched aura has a "When" button (cycles
  Any / Cbt / Inst / Wld) to restrict its cue to everywhere, only in combat,
  only in instances, or only in the open world. Handy for muting world-noise
  buffs in dungeons, or vice versa.

## v0.18.0

- **Spoken cues (text-to-speech).** Pick "Speak the name (TTS)" as a buff's
  or debuff's gained/faded sound and AuraCue says the aura's name aloud — a
  big help for blind / low-vision players, and it works in instances for
  self-cast buffs. New Speech voice / rate / volume controls in the Audio
  section.

## v0.17.1

- **"Only show ones trackable in instances" filter** on the aura picker —
  narrows the list to auras that work inside instances (debuffs, and buffs
  you can cast), hiding open-world-only auras.

## v0.17.0

- **Consistent, predictable cues.** Each watched aura now uses one fixed
  tracking method instead of switching between several:
  - A buff **you cast** is tracked by your cast — same behavior in every zone,
    including instances (gained on cast, faded on its duration).
  - Anything else is tracked by reading the aura, which the game only allows
    outside instanced combat — so there it stays quiet instead of firing
    wrong.
  - Hover a watched aura to see which method it's using.
- Removed the old "hold and re-check on combat end" behavior that caused
  late/bursted faded cues. Combat now ends with a silent re-sync.

## v0.16.0

- **Debuff cues in instances (private auras).** Most boss / mob debuffs in
  delves and dungeons are "private auras", which addons can't read — but the
  game can play a sound when one is applied to you. AuraCue now registers
  your watched debuffs' Gained sound that way, so you get an audio cue for
  them in instanced content. (It's sound-only on apply there — no visual, no
  faded — since that's all the game exposes.)

## v0.15.0

- **Self-buff cues now work in instances (delves / dungeons).** The game
  blocks reading your auras there, but not your own spell casts — so cues for
  a buff you cast yourself now fire from the cast: "gained" the moment you
  cast it, and "faded" after its duration (learned automatically while you're
  in the open world). Works for buffs whose aura matches the cast spell.

## v0.14.2

- **Stop watched auras flipping to "faded" when combat starts.** If a read
  comes back empty *during combat* (the game can hide aura state there), the
  aura is now held at its last-known state and re-checked when combat ends,
  instead of firing a faded cue. Added `/cue debug` to inspect how the game
  reports your watched auras in and out of combat.

## v0.14.1

- **Fix: cues now work in combat.** Watched auras were all reported as
  "faded" the moment combat started and "gained" again when it ended. The
  game hides aura spell IDs during combat, and the tracker was reading them
  to match; it now checks each watched aura by its known ID instead, which
  works in and out of combat.

## v0.14.0

- **Import / export.** A new Sharing section on the main page lets you export
  the current spec's profile, or the whole aura catalog, to a copy-paste
  string — to back up or share with others — and paste one in to import. No
  libraries required.
- **`/cue gather`.** Catalogs every aura currently on nearby units (your
  target, focus, nameplates, party / raid) in one go — handy on a target
  dummy or out in the world to fill the picker quickly. (Enemy spell IDs are
  hidden by the game inside instances, so gather there with that in mind.)

## v0.13.0

- **Per-spec profiles.** Your tracked auras and window settings are now saved
  separately for each character *and* specialization, and switch automatically
  when you change spec — so a tank and a healer spec can watch different
  things. The main page shows which spec you're editing. Your existing setup
  moves into your current spec on first login.

## v0.12.1

- Left-clicking the minimap button now opens *and* closes the options (it
  toggles). Removed the "Drag" line from its tooltip.

## v0.12.0

- **Minimap button.** Left-click opens options, right-click toggles AuraCue
  on/off, and you can drag it around the minimap. Hide or show it with the
  "Show minimap button" option in General.

## v0.11.0

- **Buffs and Debuffs are now separate pages in the settings list**, instead
  of tabs inside one panel. The main AuraCue page holds the general and
  audio settings; "Buffs" and "Debuffs" each get their own page (in the left
  sidebar) with that kind's window appearance and its watched-aura editor.
  Cleaner and less cluttered, and each picker only offers auras of its kind.

## v0.10.4

- Fix the "Audio channel" label overlapping the description above it (long
  descriptions now reserve enough height).
- Remove the large empty gap under "…or by spell ID" (the add-status text
  now sits inline next to the Add button instead of on its own blank line).

## v0.10.3

- Fix the divider between tracked auras being overlapped by the row's sound
  dropdowns (rows now have enough height for both lines plus the divider).

## v0.10.2

- **"Only show auras I cast" filter** on the aura picker — narrows the list
  (and the live search) to auras you applied yourself, instead of every aura
  that's ever landed on you.

## v0.10.1

- **Live aura search.** Typing in the search box now shows matching auras
  instantly in a list right below it — the list narrows as you type, so you
  no longer have to open the dropdown to check. Click a result to add it.
- **Divider lines** between tracked auras so the two-line rows are easier to
  tell apart.

## v0.10.0

- **Storage split (groundwork for profiles & sharing).** The catalog of
  auras seen on you is now **account-wide** — it builds up once and is shared
  across all your characters — while your tracked auras and settings live in
  a **per-character profile**. Your existing setup migrates automatically on
  first login; nothing to do. (Per-spec profiles and import/export build on
  this next.)

## v0.9.1

- **Search the aura picker.** A search box next to "Add an aura" filters the
  list by name or spell ID.
- **Spell tooltips on highlight.** Highlighting an aura in the picker now
  shows that spell's tooltip.
- **Better hover info.** Hovering a watched aura shows its spell tooltip
  (plus source / dungeon when known) instead of "source unknown".

## v0.9.0

- **Separate sounds for gained vs faded.** Each watched aura now has two
  sound pickers — one played when it's gained, one when it fades — each with
  its own preview button and a "None (silent)" option. New auras default to
  Rise on gained and Fall on faded. Existing auras keep their current sound
  for both.
- Watched-aura rows are now two lines to fit both sound pickers.

## v0.8.0

- **Separate windows for buffs and debuffs.** Each kind now has its own
  on-screen flash window with independent size, position, color, and
  on-screen time — so (for example) debuffs can be a big red warning in the
  center while buffs are a smaller teal note off to the side. The window
  settings live right under the Buffs / Debuffs tabs and follow whichever
  tab you're on.
- **The per-aura test button (▸) now previews the visual too**, not just the
  sound — it fires the cue exactly as it would in play.
- Existing window settings are carried over to both new windows on first
  load.

## v0.7.1

- Sharper addon icon (antialiased PNG).

## v0.7.0

- **Distinct bundled cue sounds.** Ships eight short, easy-to-tell-apart
  tones — Rise, Fall, Ping, Beep, Double, Triple, Chirp, Thud — so you can
  give different auras different sounds and recognize them by ear. Replaces
  the previous built-in game sounds.
- **Addon icon.** AuraCue now has its own icon in the addon list and
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
  AuraCue records the dungeon, and debuffs file themselves under that
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

- Fix a Lua error on login ("attempt to index global 'AuraCueDB'") caused
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
- **Built for Midnight (12.x) restrictions.** AuraCue only reads the
  player's own auras, which Blizzard keeps non-secret even in combat, and
  routes every value through a secret-value guard — so it works inside raid
  encounters, Mythic+, and PvP where addons can't read enemy combat data.
- **Slash commands** (`/cue`): `add <spellID>`, `remove <spellID>`, `list`,
  `test`, `toggle`, `unlock` / `lock`, `reset`, `status`.
- **Addon Compartment** button: left-click for options, right-click to
  toggle on/off.
