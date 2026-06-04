# Releasing

The BigWigs packager runs automatically on annotated tag push. Versions
follow `vMAJOR.MINOR.PATCH` (e.g. `v0.1.1`). Tags, the TOC `## Version:`
line, and CHANGELOG entries all use the `v` prefix.

## Pre-flight checklist

1. Add a new entry at the top of `CHANGELOG.md` for the version you're
   about to release.
2. Bump `## Version:` in `AuraCue.toc` to match the tag you'll push.
3. Sanity-check Lua syntax locally:

   ```bash
   for f in *.lua; do luac -p "$f" || break; done
   ```

4. Commit and push to `main`.

## Cutting a release

```bash
git tag -a v0.1.1 -m "v0.1.1"
git push origin --follow-tags
```

`--follow-tags` pushes the current branch plus any annotated tags
reachable from `HEAD`, so the tag's commit always reaches the remote
before the release workflow's `actions/checkout` step runs.

The workflow `.github/workflows/release.yml` triggers on tag push and runs
`BigWigsMods/packager@v2`. It will:

- Read `.pkgmeta`, drop the paths listed under `ignore:`, and package the
  remaining files into a `AuraCue/` folder inside the zip.
- Generate a release zip named `AuraCue-v0.1.1.zip`.
- Upload to CurseForge (`CF_API_KEY`), Wago (`WAGO_API_TOKEN`), and create
  a GitHub Release attached to the tag (`GITHUB_TOKEN`, auto-provided).
- Use `CHANGELOG.md` as the release-notes body (see the `manual-changelog:`
  block in `.pkgmeta`).

## Required GitHub secrets

Configure under Settings → Secrets and variables → Actions:

| Secret | Source |
| --- | --- |
| `CF_API_KEY` | <https://legacy.curseforge.com/account/api-tokens> |
| `WAGO_API_TOKEN` | <https://addons.wago.io/account/apikeys> |
| `GITHUB_TOKEN` | (auto-provided; nothing to configure) |

## Project IDs

Once the CurseForge and Wago projects exist, add these lines to
`AuraCue.toc` so the packager publishes to the right projects:

```
## X-Curse-Project-ID: 123456
## X-Wago-ID: abc123def
```

They're intentionally omitted until the projects are created.

## First-time project setup

When creating the project on CurseForge / Wago for the first time, the
**Project Summary** field (separate from the long description) wants ~150
characters of plain text. The recommended copy sits at the top of
`CurseForge-description.md` inside an HTML comment.

## Bundled assets

Cue sounds (`Sounds/*.mp3`) and the addon icon (`Icon.png`) are procedurally
generated and committed. Regenerate with the scripts in `tools/`:

```bash
python3 tools/make_sounds.py   # writes Sounds/rise.mp3 ... thud.mp3
python3 tools/make_icon.py     # writes Icon.png
```

`make_sounds.py` is stdlib-only for synthesis but needs `ffmpeg` on PATH for
the WAV → MP3 step (encoder `libmp3lame`). Edit the `TONES` table to change
the palette. `make_icon.py` needs `Pillow` (`pip install Pillow`); it draws
the icon at 4x supersample and downscales with LANCZOS for clean edges.

`tools/` and `assets/` are excluded from the packaged zip (see `.pkgmeta`);
`Sounds/` and `Icon.png` ship.

## Shipped starter catalog (Data.lua)

`Data.lua` can carry a base aura catalog so new users open the picker to a
useful list. To build or update it:

1. In-game, build the catalog you want to ship (play, `/cue gather`, normal
   use), then Options → Sharing → **Export catalog** and copy the `CSC1!…`
   string.
2. Paste it into `ns.BASE_CATALOG.string` in `Data.lua` and bump
   `ns.BASE_CATALOG.version` by 1.

On load, if the bundled `version` exceeds what a player has already received
(`AuraCueDB.baseVersion`), the catalog is merged into their list — only auras
they don't already have are added, and a starter aura a player deletes stays
gone until you bump `version` again. Leaving `string` empty ships no data.

## Libraries

The minimap button needs LibStub / CallbackHandler-1.0 / LibDataBroker-1.1 /
LibDBIcon-1.0. These are **not committed** — the packager fetches them fresh
into `Libs/` at build time via the `externals` block in `.pkgmeta` (and
`Libs/` is gitignored). In a local dev checkout the libraries are absent, so
the minimap button simply doesn't appear; everything else works. To test the
button locally, run the packager dry-run (which populates `Libs/`) or copy
the libs in from another addon.

## Manual packaging (for testing)

```bash
curl -s https://raw.githubusercontent.com/BigWigsMods/packager/master/release.sh | bash -s -- -d
```

The `-d` flag skips uploading. Output ends up in `.release/`.
