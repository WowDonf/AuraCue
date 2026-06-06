# Changelog

## v0.70.3

- Fixed the missing-buff checklist churning memory: it scanned your auras by
  name for *every missing buff, every update*. Now it builds the name list at
  most once per update — and not at all when nothing's missing — and updates a
  little less often.

- Cut idle memory churn from on-screen timers: duration **bars** only re-format
  their countdown text when the shown value changes (not every frame), and the
  checklist **ticker** caches its text width instead of measuring each frame.

## v0.70.1

- Big reduction in memory churn from the missing-buff checklist: it now updates
  at most a few times a second (coalesced) instead of on every aura tick and
  every spell cast, and the by-name aura lookup no longer allocates each call.

## v0.70.0

- **Find a setting.** A search box on the main AuraCue page lists matching
  settings as you type and jumps straight to the page each one lives on.

## v0.69.0

- **First-run welcome.** New installs get a short welcome with quick links to
  add auras (jumps to Buffs/Skills) or open settings. Re-open it any time with
  `/cue setup` or the "Show the welcome guide" button in Global Settings.
  Existing setups are treated as already onboarded, so it won't nag on update.

## v0.68.3

- Renamed settings pages: **Checklist → Missing Buffs**, **Manage Auras →
  Organize Auras**, **Sharing → Profile** (keeping the list alphabetical, with
  Missing Buffs after Debuffs).

## v0.68.2

- The checklist ticker no longer has a trailing dot after the last item.

## v0.68.1

- The **weapon enchant** now appears as a row in the checklist (when watched), so
  it gets the same **Flash** and **Ticker** ticks as your buffs.

## v0.68.0

- Checklist gets a **scrolling ticker** — a marquee of selected missing buffs
  that drifts left. It's **per buff** (a Ticker tick per row, like Flash), with
  a width and Move / Lock position on the Checklist page.
- The missing-buff **flash colour** is now configurable (a colour picker beside
  the ticker controls).

## v0.67.0

- Checklist buffs now match by **name**, so a same-named different rank (e.g.
  a 1-star vs 2-star flask) counts as present.
- Each checklist buff has a **Flash** tick — while any flash-tagged buff is
  missing, a red screen-edge glow pulses to grab your attention.

## v0.66.2

- Checklist can now warn about a missing **weapon enchant** (oil / sharpening
  stone). These are temporary weapon enchants, not auras, so they don't appear
  in the catalog — turn on "Warn if a weapon enchant is missing" on the
  Checklist page and the box shows a weapon's icon while either weapon has no
  enchant.

## v0.66.1

- Checklist polish: the **Add a buff** picker now uses the same grouped submenus
  as the Buffs/Debuffs pages, the **Search** box shows a live autocomplete popup
  of matching buffs to click, and **Test** now shows sample icons even when the
  checklist is empty (and positions the box) so you can place it first.

## v0.66.0

- New **Checklist** page: build a list of buffs you want kept up, and a movable
  on-screen box shows an icon for each one that's currently **missing** (an
  empty box means you're fully buffed) — handy as a pre-pull check. Add buffs
  from your catalog or by spell ID; set the icon size, icons per row, and
  position (Move / Lock / Test). Per character and spec.

## v0.65.0

- **Profile presets.** Save a spec's current setup as a named, account-wide
  preset and apply it to any character/spec later — for quickly switching
  between raid, Mythic+, and PvP configurations. On the **Sharing** page, or via
  `/cue preset` (`save <name>`, `<name>` to apply, `list`, `delete <name>`).

## v0.64.0

- **Detects aura/stance swaps in combat.** Aura reads are masked in combat, but
  your own casts aren't — so AuraCue now learns which auras replace each other
  (from swaps it sees out of combat) and, when you cast a replacement mid-fight,
  fires the old aura's "lost" in real time and refreshes any conditional cue
  that depended on it. Catches an aura you switched off by accident.

## v0.63.7

- Conditional cues gated on an aura that combat masks (e.g. **"only while
  Devotion Aura is active"**) now evaluate correctly in combat: the gate
  remembers the aura's last reliable out-of-combat reading and uses that while
  the live read is masked, instead of treating it as absent.

## v0.63.6

- Permanent auras (Devotion Aura, stances, toggles) no longer fire a false
  **"lost"** when entering combat. Combat can mask the aura's read a moment
  before the combat flags engage, so the engine now holds such an aura on an
  absent read and only fires "lost" if it's still gone a beat later and you're
  confirmed out of combat.

## v0.63.5

- Re-baseline tracking **silently on entering combat** (matching the existing
  re-sync on leaving combat), so an aura whose ID read gets masked the instant
  combat starts is held rather than firing a false "lost". `/cue debug` now also
  reports each aura's permanent flag and name-readability.

## v0.63.4

- Further fix for a false **"lost"** when entering combat: a **permanent** aura
  (one that can't expire — auras, stances, toggles like Devotion Aura) is now
  held rather than faded when its read is masked in combat, since it can't have
  actually dropped.

## v0.63.3

- Fixed a false **"lost"** cue firing on a still-active aura when entering combat
  (e.g. Devotion Aura at a training dummy). Before firing "lost", the engine now
  confirms the aura is really gone by name — entering combat can mask an aura's
  ID read even though it's still on you.

## v0.63.2

- Conditional cues now detect the gating aura more reliably: if the spell ID you
  entered is the *cast* ID (different from the aura's own ID), it falls back to
  matching by name, so **"Only while it's missing"** correctly suppresses while
  the aura is up. The gate also only fires on a confirmed read.

## v0.63.1

- Fixed **"Only while it's missing"** (conditional cues) sometimes firing while
  the required aura was present. Switching modes now flips only the mode and can
  no longer accidentally clear the requirement (which made the cue fire
  unconditionally).

## v0.63.0

- Conditional cues can now carry a custom **alert text**. With a "Require
  another aura" gate set, use **Set alert text…** in that submenu to override
  both the on-screen flash and the spoken phrase for that cue (supports
  {name}). Clearing the requirement clears the alert text too.

## v0.62.1

- Fixed **Clear requirement** (Require another aura) appearing to do nothing —
  it now closes the menu and refreshes so the cleared state shows immediately.

## v0.62.0

- **Conditional cues.** A watched aura's Edit (right-click) menu now has
  **Require another aura** — gate a cue so it only fires while some other aura
  is **active**, or only while it's **missing** (e.g. warn that a self-buff
  dropped, or only alert on a proc while a stance is up). Set the gating aura by
  spell ID and pick active/missing. (Best-effort in instanced combat, where the
  gating aura may be hidden from addons.)

## v0.61.0

- The on-screen flash can now show the **spell icon** above the text. Turn it on
  per window (buffs / debuffs) with "Show the spell icon in the flash" on the
  Appearance page.

## v0.60.15

- Further fix for phrase text scrolled off the left edge: the cursor reset now
  also runs on the next frame (once the field is laid out), so the phrase shows
  from the start without having to click in and press an arrow key.

## v0.60.14

- Fixed phrase text appearing blank in the Audio fields (and the spoken-text
  dialog) when it was actually scrolled off the left edge. The cursor now
  resets to the start after the text is set, so the phrase is always visible.

## v0.60.13

- Fixed the greyed "{name} gained" / "{name} lost" placeholder not appearing in
  the empty phrase fields. The font is now set with an explicit path so the
  placeholder text actually renders.

## v0.60.12

- Fixed the Audio **Gained / Lost phrase** fields showing blank after a reload
  even though the phrase was still stored and working. The field now re-reads
  its value whenever it becomes visible, so what you entered shows again.

## v0.60.11

- Fixed a sound set to **None (silent)** still firing — a gained event with no
  sound was falling through to the faded sound (and vice versa), so a "speak"
  on the other event spoke anyway. Each event now uses strictly its own sound,
  and "None" is truly silent.

## v0.60.10

- Fixed the timer-bar window going blank after **Lock bars**, even when auras
  were actively tracking. Locking now drops only the move-mode sample bars and
  restores the real bars for whatever's currently active.

## v0.60.9

- Fixed the **Bar font** dropdown erroring on open (the menu's label is a
  protected region that blocks SetFont/CreateFontString). Each font's preview
  now uses a pre-built font object applied with SetFontObject, so the dropdown
  opens cleanly and still shows every name in its own font.

## v0.60.8

- Began fixing the Bar font dropdown error (superseded by v0.60.9).

## v0.60.7

- Timer bars can now show the spell icon on the **right** of the bar instead
  of the left — a new "Icon on the right" toggle sits beside "Reverse fill
  direction".

## v0.60.6

- The **Bar texture** and **Bar font** dropdowns now preview each option: the
  texture dropdown shows a swatch of each bar style, and the font dropdown
  renders each name in its own font.

## v0.60.5

- Fixed the Audio **Gained / Lost phrase** fields going blank after a reload
  when set to the default wording ("{name} gained"). A leftover migration was
  clearing them on every load; it's gone, so a phrase you enter now sticks and
  shows in the field.

## v0.60.4

- The "show a bar on every watched aura" override is now **two** toggles on the
  Bars page — one for **buffs**, one for **debuffs** — so you can force bars on
  all buffs, all debuffs, or both. Each still overrides the per-aura toggles
  without changing them.

## v0.60.3

- Moved the **Timer bars** settings onto their own **Bars** page in the settings
  list (between Audio and Buffs/Skills), so the Appearance page is back to just
  the buff/debuff flash windows.

## v0.60.2

- Timer bar countdowns now read in minutes / hours once over a minute, rounded
  up — 90s shows "2m", 60 min "1h", 120 min "2h". Under a minute still counts
  seconds (with tenths in the last 10s).

## v0.60.1

- Renamed the "Faded" event to **"Lost"** everywhere it's shown — the
  spoken / flashed word ("{name} lost"), the **Gained / Lost** phrase and sound
  fields, the **L** row column, the Lost flash colour, and the docs. Your saved
  cue settings are unaffected.

## v0.60.0

- **On-screen timer bars.** A watched aura can now show a depleting duration
  bar while it's active — turn it on per aura from its **Edit** menu ("Show a
  timer bar while active"), or flip on **"Show a bar on every watched aura"** to
  get one for all of them (it overrides the per-aura toggles without changing
  them). Bars stack in one movable window (icon + name + countdown), coloured by
  buff/debuff colour. Configure the window on the **Appearance** page: enable,
  size, growth direction, max bars, the **bar texture** and **font** (any
  SharedMedia statusbar / font your other addons provide), buff/debuff bar
  colours, text outline + shadow, reverse fill, and Move / Lock / Test. Driven
  by the durations the addon already learns, so cast
  buffs get an estimated bar even in instances; auras it can't read in instanced
  combat still won't show there (same limit as the cues).

## v0.59.3

- Dropped "missing-buff reminders" from the addon's description — AuraCue
  doesn't remind you about missing buffs, so the wording was misleading.

## v0.59.2

- Renamed the **Buffs** settings page to **Buffs/Skills**, since it also covers
  the castable abilities the spellbook seeds into the catalog.

## v0.59.1

- Fixed the greyed "{name} gained" / "{name} faded" placeholder not appearing in
  the Audio phrase fields (and the per-cue spoken-text dialog). The font was set
  in a way that could leave the text invisible; it's now applied reliably.
  (Placeholder shows only when the field is empty — clear a phrase to see it.)

## v0.59.0

- The "AuraCue loaded" chat message at login is now **off by default**. Turn it
  back on with **Show login message in chat** under Global Settings. (The
  one-time CueSense data-migration notice still shows when it applies.)

## v0.58.2

- The Custom groups dropdown on Manage Auras now **filters the list** to the
  chosen group, with an **All groups** entry at the top to clear the filter.
  Picking a group both narrows the list and targets it for Rename / Delete.

## v0.58.1

- The add-an-aura picker now stays on-screen and scrolls: both the menu and each
  group submenu are capped to ~55% of screen height instead of overflowing off
  the bottom (a class group can hold a lot of spells now the spellbook seeds the
  catalog).
- The Audio page's Gained/Faded phrase fields now actually show "{name} gained"
  / "{name} faded" as greyed placeholder text. They were pre-filled with the
  literal default, so the placeholder never appeared; the default is now blank
  (same spoken result) and existing profiles holding only the old default are
  cleared so the placeholder shows.

## v0.58.0

- **Audio** is now its own page in the settings list (moved off the main page),
  with a dedicated **Text-to-speech** section heading for the voice and
  spoken-phrase settings. The main page keeps the global toggles. The
  subcategories are now ordered alphabetically.

## v0.57.3

- Gained/faded phrase fields now show their default as greyed placeholder text
  while empty, so it's clear what plays if you leave them blank: the Audio
  page's general-phrase fields show "{name} gained" / "{name} faded", and a
  cue's Set-spoken-text override fields show your general format.

## v0.57.2

- Per-cue spoken overrides now honor **{name}** too. Set a gained/faded override
  to "{name} activated" to hear "Bloodlust activated"; a phrase with no token
  (like "Damage now") still speaks exactly as typed. The Set-spoken-text dialog
  notes this and the field hint shows an example.

## v0.57.1

- Spell IDs you hand-link to a cue ("Add other spell IDs by hand") now also get
  added to the **Manage Auras** catalog, like a by-ID add does — each linked ID
  takes the cue's buff/debuff kind (but not its class, since linked IDs are
  usually cross-class equivalents). Clearing linked IDs still leaves their
  catalog entries in place.

## v0.57.0

- Gained/faded phrase testers for text-to-speech. The "Set spoken text" dialog
  now has a **>** button next to each phrase that speaks exactly what you'd
  hear (your typed phrase, or the general format if left blank). The main page's
  speech test is now split into **Test gained phrase** / **Test faded phrase**,
  which read your general formats aloud with a sample aura name.

## v0.56.2

- Fixed an "action blocked" error when opening the options panel during combat.
  Blizzard protects the Settings panel in combat, so AuraCue now declines with a
  note ("try again afterwards") instead of tripping the error.

## v0.56.1

- Adding an aura by spell ID now also adds it to the **Manage Auras** catalog,
  not just the watched list — so you can group, edit, or hide it there like any
  other aura. An ID added from the Debuffs page is also filed as a debuff (it
  used to default to a buff).

## v0.56.0

- Three new open/close sound pairs, so the only ascending-gained /
  descending-faded set is no longer just rise/fall: **Open/Close** (a smooth
  pitch sweep), **Unfold/Fold** (a three-note arpeggio), and **Bloom/Wilt** (a
  warmer, lower two-tone). Pick them per cue in the Gained / Faded dropdowns.

## v0.55.1

- Updated for WoW 12.0.7 (Interface 120007). Verified the addon's full API
  surface against the 12.0.7 changes — no removed or signature-broken calls are
  used. The scroll methods the options panels use (GetVerticalScroll) are now
  flagged as possibly-secret in restricted contexts, which a config frame never
  is; guarded them anyway as a precaution.

## v0.55.0

- Performance: the picker no longer rebuilds and re-sorts the entire catalog
  every time you type in its search box — the list is cached and rebuilt only
  when the catalog actually changes. This matters now the catalog is seeded
  from your spellbook and can be large.
- Internal cleanup (no behavior change): shared a mount/riding resolver and a
  catalog-entry builder across the core; consolidated the two custom edit
  dialogs behind one factory; lifted the watched-row widget builders out of the
  panel builder; assorted small de-duplication.

## v0.54.3

- Performance: the background catalog scan (which fills the picker) no longer
  runs a full double aura sweep on every aura change during combat — it's
  throttled to at most once a second, since it's only a convenience, not
  something cues depend on. The alias/auto-combine rebuild also now indexes the
  catalog by name once instead of re-scanning the whole (much larger, now
  spellbook-seeded) catalog for every watched aura. No behavior change.

## v0.54.2

- Riding / skyriding flight abilities (Skyward Ascent, Surge Forward, Whirling
  Surge, etc.) are now catalogued and filed under the **Mounts** group instead
  of being dropped, so they sit with your mounts and are covered by the "Hide
  mounts" filter. (Reverses the removal from v0.54.1.)

## v0.54.1

- Riding / skyriding flight abilities (Skyward Ascent, Surge Forward, Whirling
  Surge, Aerial Halt, etc.) are no longer added to the catalog — they were
  getting pulled in by the spellbook pre-load and by casting them, but never
  make useful aura cues. Any that were already in your catalog are removed on
  login.

## v0.54.0

- **Spellbook pre-loading.** Your character's active spells are now added to
  the catalog automatically on login, so your class's abilities are pickable
  right away instead of having to be cast once to "learn" them. The catalog is
  account-wide, so each character you log into fills in that class's spells.
  Existing entries are never overwritten (anything we've already learned the
  real kind/source/group for keeps its detail), and the picker refreshes when
  you learn or swap spells. Spellbook spells default to "buff" — flip the kind
  from the Edit menu or Manage Auras if one is actually a debuff.

## v0.53.0

- Replaced the per-row "When" (Any/Cbt/Inst/Wld) cycle button with an **Edit**
  button that opens all the per-cue options in one menu: when to fire, spoken
  text, treat-as buff/debuff, and the combine/alias options. (Right-click still
  works too.)

## v0.52.1

- The watched-row Group field now shows the aura's effective heading (its
  custom group, or the auto bucket like a class/dungeon) instead of being blank
  for auto-grouped auras. Editing it still sets a custom group.
- Removed the now-redundant Group button on Manage Auras rows (group is set in
  the Edit dialog).

## v0.52.0

- **Custom spoken cues.** When a cue uses "Speak the name (TTS)", you can now
  choose what it says:
  - **General** (main Audio settings): "Gained phrase" / "Faded phrase" with a
    `{name}` placeholder — e.g. change "{name} gained" to "{name} up". Applies
    to all spoken cues.
  - **Per ability** (right-click a watched aura → "Set spoken text…"): a literal
    phrase that overrides the general one — e.g. make Bloodlust say "Damage
    Now".

## v0.51.0

- **One group, everywhere.** The watched-row Group box used to set a separate
  per-spec "category" that only affected the watched list. It now sets the same
  single, account-wide custom group used by the picker, Manage Auras, and the
  Edit dialog — so a group set in any place shows everywhere. Ungrouped auras
  auto-group by class / mount / dungeon (the same logic as the picker), and any
  custom watched-list headings you'd set are migrated into custom groups on
  login.

## v0.50.0

- The Manage Auras **Edit** dialog now also sets the aura's **Custom group**.
- Fixed custom groups looking like they came and went between the options
  pages: setting a group now refreshes every page, not just the one you set it
  from. (Groups are stored account-wide and do persist; the inconsistency was a
  missing refresh.)

## v0.49.1

- Added a **Class** filter to the Manage Auras page (a class, "(untagged)", or
  all).

## v0.49.0

- Removed the Boss field from the Edit dialog.
- Added filters to the Manage Auras page: a **Kind** dropdown (All / Buffs /
  Debuffs), **Hide mounts**, and **Only un-grouped auras**, alongside the
  existing search and Show-hidden toggle.

## v0.48.1

- Removed the Name field from the Edit dialog (added by mistake).
- Editing an aura's Kind in the Edit dialog now also moves a watched cue for it
  between the Buffs and Debuffs pages automatically (dungeon/source edits sync
  to the cue too).

## v0.48.0

- The Manage Auras **Edit** dialog now also edits an aura's **Name**, **Class**
  (a dropdown — fix a mis-tag or assign one manually), **Kind** (buff/debuff),
  and **Boss** flag, alongside Dungeon and Source.

## v0.47.0

- Watched-aura tooltips are tidier: dropped the "Dungeon:" and "Tracked by:"
  lines, and the "Also triggers on:" line now shows names alongside IDs (e.g.
  "2825 Bloodlust").
- On the Appearance page, "Also flash the screen edges" is now "Flash the
  screen edges" and sits next to "Show on-screen flash".
- Manage Auras: the hidden toggle is relabeled "Show hidden auras", and each
  row has an **Edit** button to change a catalogued aura's stored details
  (dungeon, discovered-by source).
- Auras applied by another player are now tagged with **that caster's class**
  when it's readable — so e.g. another Druid's Mark of the Wild files under
  "Druid", not just your own casts.

## v0.46.3

- Self-applied debuffs are now filed under "Debuffs" in the watched list
  instead of the dungeon they were cast in. Already-added ones get moved on
  login (only if still on the auto dungeon label).

## v0.46.2

- Moved the Appearance page above Buffs in the settings list.

## v0.46.1

- Moved "Copy from another character" to the top of the Sharing page.

## v0.46.0

- **Copy a profile from another character.** The Sharing page has a new "Copy
  from another character" section — pick any saved character/spec profile on
  your account and copy it into the current one, no export string needed. It
  makes an independent copy and confirms before overwriting.

## v0.45.0

- **Decluttered the Buffs/Debuffs pages.** The on-screen window look (colors,
  edges, size, on-screen time, move/reset/test) moved to a new **Appearance**
  page in the left list — covering both windows in one place. The Buffs and
  Debuffs pages now open straight to the watched-aura list and the add
  controls, instead of a wall of appearance sliders.

## v0.44.0

Engine consolidation and bug-fix pass (from a code review of the tracking core):

- **Fixed: instanced-debuff sounds never played.** The private-aura sound
  registration was gated on a setting that didn't exist, so it silently never
  ran. It now checks the real audio master switch.
- **Fixed: cast-tracked "faded" could stop firing** after combat ended, a zone
  change, or a spec swap — a re-synced cue wasn't re-confirmed, so its drop went
  uncued until the next cast. Re-syncs now re-confirm present cast cues.
- **Fixed: stale tracking state** when removing a cue, swapping spec, importing
  a profile, or flipping a cue's kind could cause a ghost or double "faded".
  All cue/profile changes now reset tracking state cleanly (and invalidate any
  pending fade timer), via a single shared path.
- Removed dead code and an unused field.

## v0.43.0

- Removed the bundled starter-catalog mechanism. The picker fills in from your
  own play, so there's no shipped seed list.

## v0.42.0

- **Flip a cue between buff and debuff.** Right-click a watched aura and pick
  "Treat as a buff/debuff" — handy when a self-debuff you cast came in on the
  Buffs side. It moves to the other page and the catalog stays in sync.
- **Custom-group management.** The Manage Auras page can now rename or delete a
  whole custom group at once (pick it from the dropdown), instead of editing
  every aura.
- **`/cue help`** lists the slash commands (and the list now includes `tts`).

## v0.41.1

- Fixed the "faded" cue not firing for a hard-cast ability (while it worked for
  a proc of the same aura). The duration-based fade timer was read before the
  duration had been learned, so on a cast it often wasn't scheduled; it's now
  scheduled with the freshly-learned duration (and re-scheduled as it updates).

## v0.41.0

- **"Combine auras with the same name" is now a Global Setting** (main page),
  applying to every cue at once instead of per-aura. Turning it on merges
  duplicate watched rows and stops the pickers offering same-named variants
  separately. The per-aura right-click option is still there for finer control.

## v0.40.1

- Turning on "Auto-combine auras with the same name" now collapses to a single
  entry: it removes any other watched cues with that name (they're already
  covered) and stops the picker offering the same-named variants separately.
  So base + proc Avenging Wrath end up as one alert, one row.

## v0.40.0

- **Auto-combine by name.** Right-click a watched aura and tick "Auto-combine
  auras with the same name" — every catalogued aura sharing that name (e.g.
  base and proc Avenging Wrath) then drives the one cue, with no need to enter
  IDs. It updates automatically as new same-named IDs are catalogued. The
  right-click menu also still lets you add specific IDs by hand. Rows show a
  small "name" / "+N" marker for what's combined.

## v0.39.0

- **One alert, multiple spell IDs.** A watched aura can now have extra trigger
  IDs, so things with more than one form — e.g. base Avenging Wrath and its
  Radiant Glory proc — fire a single cue instead of needing two. Right-click a
  watched row to add the other IDs (comma-separated); a `+N` marker shows when
  a cue has aliases. Works for sound, visual, cast-tracking, and the in-
  instance private-aura sound.

## v0.38.1

- Class grouping now works for abilities that **proc** rather than being cast
  (e.g. Avenging Wrath under Radiant Glory). The class tag is derived from the
  aura itself — any of your own known-spell auras (not mounts) — so it no
  longer depends on catching a cast event. Existing entries get the tag the
  next time the aura is seen.

## v0.38.0

- Castable abilities now show up in the picker even when they don't apply a
  readable aura. Previously only abilities whose cast applied a matching aura
  were catalogued, so a lot of what you cast was missing. Now any known
  ability you cast (not a mount) is offered and cast-tracked, filed under your
  class. It fills in as you use your abilities; kind defaults to buff.

## v0.37.0

- Abilities you cast are now auto-filed under **your class** in the picker
  (e.g. Earth Shield → "Shaman"). The class is recorded from the character
  that cast it (the game has no spell→class lookup), so it covers what you
  cast yourself and fills in as you use abilities; mounts and toys are
  excluded. Auras you didn't cast still fall into the other buckets.

## v0.36.0

- Added a **"Find an ID" → Search Wowhead** helper under each picker. Type a
  spell name and it gives you a copyable Wowhead search link to open in your
  browser (addons can't browse the web), where the spell ID is in the URL.

## v0.35.0

- The picker now catalogs auras from the spells you **cast**, not just ones
  read off you out of combat. Previously a buff/debuff applied during combat
  couldn't be recorded (the aura list hides spell ids in combat), so lots of
  cast abilities never showed up to add. Casting now queries that exact id —
  which works in combat — and files the aura it applies. (Catches abilities
  whose aura shares the cast's spell id; a few procs with a different aura id
  still rely on being seen out of combat.)

## v0.34.4

- Self-applied debuffs now group under "From you / your pet" instead of being
  filed under the dungeon (or Boss) where you happened to cast them. The
  self/mine check now applies to debuffs too, not just buffs.

## v0.34.3

- Fixed self-buffs/passives (e.g. a Shaman's Reincarnation) being mislabelled
  as boss debuffs. An aura is only treated as a boss aura now if it's harmful
  and not one of your own, and existing catalogs are cleaned up on load.

## v0.34.2

- Fixed panel widgets (watched-row close buttons, dropdowns, checkmarks)
  showing through the aura search/hide list. The list now sits on a higher
  layer with an opaque background, so it cleanly covers what's behind it.

## v0.34.1

- Fixed the aura search/hide list overlapping the search box (its top row and
  the ✕ button sat over the search bar). It now opens cleanly below the row.

## v0.34.0

- Groundwork to **ship a starter aura catalog** with the addon (`Data.lua`).
  When populated, a fresh install opens the picker to a useful list instead
  of an empty one; it merges in once per bundled version and never clobbers a
  player's own changes. (Ships empty for now — see RELEASING.md to fill it.)

## v0.33.0

- Auras you already track are now **always** left out of the Add picker
  (it's the default — no more checkbox), so the list only shows things you
  could still add.
- New Show filters: **Only permanent auras** / **Only timed auras** (from the
  aura's duration, mutually exclusive) and **Only role auras** (Tank /
  Healer / DPS-tagged). These fill in as you encounter the auras.

## v0.32.0

- More ways to thin the "Add" dropdown via the Show filter: **Hide mounts**,
  **Hide ones I already track**, and **Only un-grouped auras** (to find what
  still needs a custom group). They combine with the existing filters.

## v0.31.2

- On the Manage Auras page, **"Show hidden auras" is now "Show only hidden
  auras"** — it filters the list down to exactly your hidden auras instead of
  mixing them in.
- **Destructive actions now warn first.** Removing auras from the catalog
  (single or selected) and clearing the whole hidden-aura list both ask for
  confirmation. The Manage page's **Clear** button is relabelled **"Clear
  selection"** to make clear it only un-ticks rows and deletes nothing.

## v0.31.1

- Renamed the "Cast by me" group (and its filter) to "From you / your pet".
  It's based on the aura's source-is-you flag, which also covers procs,
  trinkets, and consumables you triggered — not only spells you actively
  cast — so the old label claimed more than the data shows.

## v0.31.0

- **Boss auras.** AuraCue now records whether an aura was applied by a boss.
  Boss debuffs get their own **Boss** group at the top of the Debuffs
  picker, there's an **"Only boss auras"** filter, and the Manage Auras page
  tags them `[boss]`. (Fills in as you encounter boss auras; instanced boss
  debuffs that are only surfaced as a private-aura sound can't be read, so
  those may not be flagged.)

## v0.30.0

- **New "Manage Auras" page.** A full edit view of your account-wide aura
  catalog in the settings list: search it, set a custom group, hide / show,
  or remove any entry. Tick rows to act on several at once — **Group…**,
  **Hide**, **Restore**, or **Remove** the whole selection in one go. (This
  is the multi-select group-assignment path; removing an aura just forgets
  it until you see it again.)

## v0.29.1

- Fixed the hide / restore / group buttons being cut off the right edge of
  the options panel. The search list is now anchored to the panel's left
  with a contained width and a short header explaining the controls, so the
  per-row buttons always fit.
- The same actions are now available from the **Add** dropdown too: plain
  click adds an aura, **Shift-click** hides/restores it, and **Ctrl-click**
  sets its custom group (shown in the entry's tooltip).

## v0.29.0

- **Reworked picker grouping.** WoW exposes no spell→class mapping, so the
  old "group by class" guess mis-sorted (mounts landed under a class, real
  abilities under "Items & toys"). The picker now groups by what the game
  can report reliably: buffs into **Cast by me**, **Mounts**, and **World &
  other**; debuffs by dungeon.
- **Custom groups.** Click the note icon on any aura (in the Search / hide
  list) to file it under a group you name — "Druid CDs", "World buffs",
  whatever — and it shows under that heading in the picker, above the auto
  buckets. Blank the name to remove it. Groups are saved account-wide.

## v0.28.0

- **Fixed "Only abilities I know" hiding almost everything.** The known-spell
  check was using a function that reports passive talents and override spells
  as *unknown* — i.e. most class abilities. It now uses the broader, correct
  check, so the filter keeps your actual abilities and only drops toys / food
  / world buffs.
- **Made hiding discoverable.** Click into the "Search / hide" box (no need to
  type) and your auras list right there, each with a ✕ to hide it (and a +
  to restore when "Show hidden auras" is on). Previously the hide controls
  only appeared once you started typing.

## v0.27.1

- You can now un-hide a single aura, not just clear the whole hidden list.
  Turn on **Show hidden auras**, search for it, and its row shows a **+**
  (restore) button and a "(hidden)" tag — click the **+** to put just that
  one back. Auras that aren't hidden still show the ✕ to hide them.

## v0.27.0

- **The picker now groups into submenus.** Buffs are grouped by the class
  that cast them ("Druid", "Mage", …) with "Items & toys" and "World &
  other" buckets for the rest; debuffs are grouped by the dungeon they were
  seen in. Each group shows its count, and searching still shows a flat list.
  Class grouping fills in as you cast abilities on each character (the game
  doesn't expose a spell's class directly, so it's tagged from the casting
  character — known spells only, so toys and food stay in their own bucket).

## v0.26.0

- **Wrangle the aura picker.** The two filter checkboxes are now a single
  **Show** filter dropdown with combinable options, including a new
  **"Only abilities I know"** filter that hides toys, food, and world buffs
  (most of the clutter) and leaves your actual class/spec abilities.
- **Hide individual auras.** Each search result has a small ✕ to permanently
  hide that aura from the picker (e.g. Cozy Fire and other one-offs). Hidden
  auras are remembered account-wide; "Show hidden auras" reveals them and
  **Reset hidden** clears the list.

## v0.25.1

- The settings carry-over from the old CueSense name now prints a
  confirmation when it runs. Note: because the game stores each addon's
  saved data under its folder name, carrying your old data over requires
  renaming the SavedVariables file `CueSense.lua` to `AuraCue.lua` once
  (with the game closed); after that, your first login imports it.

## v0.25.0

- **Renamed to AuraCue.** The addon is now a general-purpose personal
  aura-alert tool — turn your own buffs and debuffs into sound, speech, or
  on-screen flashes for proc alerts, cooldown windows, and debuff
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
