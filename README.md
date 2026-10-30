# CK3ToEU4 for macOS (unofficial)

Convert your **Crusader Kings III** save into a **Europa Universalis IV** mod, natively on a Mac. This build also adds unofficial support for **CK3 1.20** and its new faith and rite system.

> [!IMPORTANT]
> **This is an unofficial port.** The converter is the work of the [Paradox Game Converters](https://github.com/ParadoxGameConverters) team: [CK3ToEU4](https://github.com/ParadoxGameConverters/CK3ToEU4). This repo only adds what's needed to build and run it on macOS, plus CK3 1.20 fixes. It isn't affiliated with them or with Paradox Interactive.
>
> **Please don't report problems with this build to the upstream project.** Open an issue [here](https://github.com/dorukyalcin/CK3ToEU4-macOS/issues) instead.
>
> **This port was made with the help of an AI coding assistant (Anthropic's Claude).** The upstream project doesn't accept AI-generated contributions, so this lives separately and hasn't been submitted to them. If they ship official macOS or 1.20 support, use theirs.

## Download and use

**Needs:** an Apple Silicon Mac (M1 or newer) on macOS 13 Ventura or later, with Crusader Kings III and Europa Universalis IV from Steam.

1. Download the zip from [Releases](https://github.com/dorukyalcin/CK3ToEU4-macOS/releases) and unzip it.
2. **First time only:** this build isn't signed with a paid Apple developer account, so macOS will block it. Open Terminal and run the following, adjusting the path if you unzipped elsewhere:
   ```bash
   xattr -dr com.apple.quarantine ~/Downloads/CK3ToEU4-macOS
   ```
   Alternatively, double-click the script, dismiss the warning, then click **Open Anyway** under *System Settings → Privacy & Security*.
3. Double-click **`Convert Latest Save.command`**. It converts your newest CK3 save, ironman included.
4. Open the EU4 launcher, add **"Converted - *save name*"** to a playset, and start a new game.

To pick a specific save or name the mod, use Terminal from the unzipped folder:

```bash
./convert.sh "My Save.ck3"            # a save from your CK3 save games folder
./convert.sh /path/to/save.ck3 MyMod  # any save, custom mod name
```

Conversion options (start date, HRE handling, de jure claims and so on) sit at the top of the script. `OPTIONS.txt` explains each one. CK3 and EU4 are found in any of your Steam library folders; if that fails, set `CK3_DIR` / `EU4_DIR`. When something goes wrong, the details are in `CK3ToEU4/log.txt`.

There's no GUI. The official Windows GUI only collects folder paths, and the script does that for you.

## Supported versions

| | |
|---|---|
| CK3 | 1.18 – 1.20. The **1.20** support is unofficial and done here; upstream supports up to 1.19. |
| EU4 | 1.37 |
| Tested with | CK3 1.20.1.2, EU4 1.37.5, macOS 26.4 on Apple Silicon, with one long campaign save (ironman, 58k characters) |

Pre-1.20 saves still go through upstream's original code paths and pass upstream's test suite, but I haven't converted a real 1.19 save with this build.

## How CK3 1.20 faiths come out in EU4

1.20 adds **rites** beneath faiths. EU4 has nothing similar, so this build maps them as follows:

| In CK3 | Example | In EU4 |
|---|---|---|
| A faith | Catholic (Roman Rite) | Catholic |
| A rite inside a faith | Insularism, Georgian Rite (still Catholic) | Catholic. EU4 can't represent rites. |
| A rite that broke away into its own faith | Ambrosian Rite → its own faith | Its own religion, "Ambrosian", in the Christian group. Catholics treat it as heretical, the way EU4 treats Protestants. |
| A custom or reformed faith | Ari (from Vajrayana) | Its own religion with its CK3 name, built on its parent |
| A split of a split, any depth | Ambrosian → a new offshoot | Its own religion. The converter follows CK3's `origin` chain back to a faith it knows. |

A converted religion takes its group, base mechanics and fallback description from its parent. Its actual rules come from the faith's own CK3 doctrines and tenets.

## Known limitations

- **Apple Silicon only.** The save decoder ([librakaly](https://github.com/rakaly/librakaly)) ships arm64-only macOS builds.
- **1.20 support is new**, and so far it's been checked against one campaign. Please report anything odd: wrong religions, borders or rulers.
- Some heresies with no recorded origin (Hussite, Joachimite, Kharijite) borrow a sibling faith as their parent, picked alphabetically (e.g. Adamites). They still end up in the right religion group, and only cosmetic details come from that parent.
- Two of upstream's flag-image tests differ from the Windows reference images by 1–2 pixels: rounding inside ImageMagick, not visible in-game.

## What this port changes

Everything is in [`patches/`](patches) as plain diffs against the pinned upstream commits:

**macOS**
- Turns on upstream's existing POSIX code for macOS. Accepts `ck3.app` / `eu4.app` game installs.
- Fixes encoding names written with a Unicode minus sign (`UTF−8`), which broke text conversion outside Windows.
- Names that are already Windows-1252 pass through. Characters Windows-1252 lacks (e.g. pinyin tone marks) become plain letters instead of blanking the whole name.
- Fixes emblem placement in generated flags on ARM: a negative offset was cast to `size_t` and clamped to 0.
- Builds with Apple's own compiler and C++ runtime, plus a static ImageMagick 7.0.10-31 (the version upstream ships on Windows), so it runs on macOS 13+ with nothing else installed.

**CK3 1.20**
- Reads the new top-level `faiths` and `rites` blocks. Characters and counties now reference a rite, which is resolved to its faith.
- Created and reformed faiths use `faith_type`/`origin` instead of `template`. When needed, the converter follows the origin chain to a faith it knows.
- Reads CK3's new `common/religion/faith_types/` folder.
- Maps 20 renamed 1.20 faiths (`theravada_faith`, `rabbinic_faith`, `vaishnava_faith`, …) in `religion_map.txt`. Includes the mapping updates from upstream's open [PR #672](https://github.com/ParadoxGameConverters/CK3ToEU4/pull/672) by Wielislaw.
- Raises the supported CK3 version to 1.20.

## Building from source

```bash
xcode-select --install       # Apple's compiler, if you don't have it
brew install cmake pkgconf
scripts/build.sh --tests     # result in dist/CK3ToEU4-macOS; --zip packages a release
```

The script downloads upstream CK3ToEU4 and commonItems at the exact commits this was tested against, applies the patches, then fetches librakaly and builds ImageMagick. Nothing outside the repo folder is touched.

## Credits and licenses

- **[CK3ToEU4](https://github.com/ParadoxGameConverters/CK3ToEU4)** and **[commonItems](https://github.com/ParadoxGameConverters/commonItems)** by the Paradox Game Converters team (MIT). Practically all of the converter is their work.
- **[librakaly](https://github.com/rakaly/librakaly)** by Nick Babcock (MIT): reads binary and ironman saves.
- **[ImageMagick](https://imagemagick.org)** (ImageMagick License): flag generation.
- Upstream's bundled [nlohmann/json](https://github.com/nlohmann/json) (MIT) and [kuba--/zip](https://github.com/kuba--/zip) (Unlicense).

This repo's own files are MIT-licensed ([LICENSE](LICENSE)). Release downloads include every bundled component's license in `licenses/`.
