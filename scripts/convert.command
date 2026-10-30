#!/bin/bash
# Converts a Crusader Kings III save into a Europa Universalis IV mod.
#
# Double-click "Convert Latest Save.command" to convert your newest CK3 save, or from Terminal:
#   ./convert.sh                          # newest save in your CK3 "save games" folder
#   ./convert.sh "My Save.ck3"            # a save from that folder, by name
#   ./convert.sh /path/to/save.ck3 MyMod  # any save, with a custom mod name
#
# Games installed somewhere unusual? Set CK3_DIR / EU4_DIR to their Steam folders.
# The mod goes into ~/Documents/Paradox Interactive/Europa Universalis IV/mod; enable it in the EU4 launcher.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DOCS="$HOME/Documents/Paradox Interactive"
SAVES="$DOCS/Crusader Kings III/save games"
EU4_MODS="$DOCS/Europa Universalis IV/mod"
STEAM="$HOME/Library/Application Support/Steam"

# Conversion options; these are the official GUI's defaults ("1" everywhere).
# OPTIONS.txt (next to this script) explains what every option and number means.
OPTIONS='start_date = "1"
dejure = "1"
i_am_hre = "1"
shatter_hre_level = "1"
shatter_empires = "1"
shatter_level = "1"
celestial_emperor = "1"
split_vassals = "1"
development = "1"
multiprovdevtransfer = "1"
siberia = "1"
sunset = "1"
dynamicInstitutions = "1"
dynasticNames = "1"
discoveredBy = "1"
tribalConfederations = "1"'

# Look for a game in every Steam library folder (Steam keeps a list of them).
find_game() {
	local name="$1" library
	local libraries=("$STEAM")
	while IFS= read -r library; do
		libraries+=("$library")
	done < <(sed -n 's/^[[:space:]]*"path"[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$STEAM/steamapps/libraryfolders.vdf" 2>/dev/null)
	for library in "${libraries[@]}"; do
		if [[ -d "$library/steamapps/common/$name" ]]; then
			echo "$library/steamapps/common/$name"
			return 0
		fi
	done
	return 0
}

CK3_DIR="${CK3_DIR:-$(find_game "Crusader Kings III")}"
EU4_DIR="${EU4_DIR:-$(find_game "Europa Universalis IV")}"
[[ -n "$CK3_DIR" ]] || { echo "Couldn't find Crusader Kings III in your Steam libraries. Set CK3_DIR to its folder." >&2; exit 1; }
[[ -n "$EU4_DIR" ]] || { echo "Couldn't find Europa Universalis IV in your Steam libraries. Set EU4_DIR to its folder." >&2; exit 1; }

save="${1:-}"
if [[ -z "$save" ]]; then
	save="$(ls -t "$SAVES"/*.ck3 2>/dev/null | head -1 || true)"
elif [[ ! -f "$save" && -f "$SAVES/$save" ]]; then
	save="$SAVES/$save"
fi
[[ -f "$save" ]] || { echo "Save not found: ${save:-no .ck3 files in $SAVES}" >&2; exit 1; }
name="${2:-}"

# This build isn't signed by an Apple developer account, so macOS quarantines it when downloaded.
# You chose to run this script, so lift the quarantine from this folder only (nothing else is touched).
if [[ "$(xattr -r "$HERE" 2>/dev/null | grep -c com.apple.quarantine || true)" != 0 ]]; then
	echo "Removing macOS download quarantine from $HERE"
	xattr -dr com.apple.quarantine "$HERE" || true
fi

mkdir -p "$EU4_MODS"
cd "$HERE/CK3ToEU4"
cat > configuration.txt <<EOF
CK3DocDirectory = "$DOCS/Crusader Kings III"
CK3directory = "$CK3_DIR"
EU4directory = "$EU4_DIR"
targetGameModPath = "$EU4_MODS"
SaveGame = "$save"
$OPTIONS
output_name = "$name"
EOF

echo "Converting: $save"
echo "CK3: $CK3_DIR"
echo "EU4: $EU4_DIR"
echo
rm -rf output
status=0
./CK3ToEU4Converter || status=$?
rm -f saveDump.txt # 300 MB decoded copy of the save, only useful for debugging
if [[ $status != 0 ]]; then
	echo
	echo "Conversion failed. Details are in: $(pwd)/log.txt" >&2
	exit 1
fi

# The converter writes to ./output; the official Windows GUI normally copies it into EU4's mod folder.
modfile="$(ls output/*.mod | head -1 || true)"
mod="$(basename "$modfile" .mod)"
rm -rf "${EU4_MODS:?}/$mod" "$EU4_MODS/$mod.mod"
cp "$modfile" "$EU4_MODS/"
cp -R "output/$mod" "$EU4_MODS/"
echo
echo "Done! \"Converted - $mod\" is in $EU4_MODS"
echo "Open the EU4 launcher, enable the mod in a playset, and start a new game."
