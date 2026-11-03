#!/usr/bin/env sh
#
# build-osf.sh - package OsmAnd rendering styles into an importable .osf file
#
# The .osf is a ZIP archive holding an "items.json" manifest plus the rendering
# styles under a "rendering/" folder.  OsmAnd reads the manifest, resolves every
# "rendering_style" item to <app data>/files/rendering/<name> and installs it
# there, so the styles show up in "Configure map > Map style".
#
# Usage:
#   ./build-osf.sh                            # default styles -> OsmAnd-Custom-Map-Styles.osf
#   ./build-osf.sh OUTPUT.osf                 # default styles -> OUTPUT.osf
#   ./build-osf.sh OUTPUT.osf A.xml B.xml     # only the listed styles
#
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# Folder holding the rendering styles that get packaged.
STYLES_DIR="$ROOT_DIR/styles"

# Styles packaged when the caller does not name any explicitly.
DEFAULT_STYLES="pranatahouse.render.xml wuzz.render.xml"

# Version of the items.json manifest.  OsmAnd refuses a manifest whose version
# is newer than the one it implements (SettingsHelper.VERSION): that constant is
# 1 before April 2024, 2 until June 2024 and 3 afterwards, so "3" would break
# the import on older OsmAnd builds.  Version 1 is accepted everywhere and is
# what the upstream OsmAnd-resources build_osf.sh emits.
MANIFEST_VERSION=1

usage() {
	cat <<EOF
usage: ${0##*/} [-h|--help] [OUTPUT.osf [STYLE.xml ...]]

Packages rendering styles into an OsmAnd .osf (importable settings package).

  OUTPUT.osf   file to write (default: $ROOT_DIR/OsmAnd-Custom-Map-Styles.osf)
  STYLE.xml    rendering styles to include (default: $DEFAULT_STYLES)

Styles are looked up in the current directory first, then in the styles/
folder next to this script.  Both "wuzz.render.xml" and "styles/wuzz.render.xml"
resolve to the same file.
EOF
}

case "${1:-}" in
	-h|--help)
		usage
		exit 0
		;;
esac

command -v zip >/dev/null 2>&1 || {
	echo "error: 'zip' is required but was not found in PATH" >&2
	exit 1
}

# Output file is the first argument; the rest are styles to include.
OUT_FILE="$ROOT_DIR/OsmAnd-Custom-Map-Styles.osf"
if [ "$#" -gt 0 ]; then
	OUT_FILE=$1
	shift
fi

TMP_DIR=$(mktemp -d)
cleanup() {
	rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

# Resolve a style to an existing file: current directory first, then the
# styles/ folder of this repo, then the repo root.
resolve_style() {
	if [ -f "$1" ]; then
		printf '%s\n' "$1"
	elif [ -f "$STYLES_DIR/$1" ]; then
		printf '%s\n' "$STYLES_DIR/$1"
	elif [ -f "$ROOT_DIR/$1" ]; then
		printf '%s\n' "$ROOT_DIR/$1"
	else
		echo "error: rendering style not found: $1" >&2
		return 1
	fi
}

STYLE_LIST="$TMP_DIR/styles.list"
: > "$STYLE_LIST"
if [ "$#" -gt 0 ]; then
	for style in "$@"; do
		resolve_style "$style" >> "$STYLE_LIST"
	done
else
	# shellcheck disable=SC2086 # DEFAULT_STYLES is a plain word list
	for style in $DEFAULT_STYLES; do
		resolve_style "$style" >> "$STYLE_LIST"
	done
fi

PKG_DIR="$TMP_DIR/package"
mkdir -p "$PKG_DIR/rendering"
while IFS= read -r style; do
	[ -n "$style" ] || continue
	cp "$style" "$PKG_DIR/rendering/$(basename "$style")"
done < "$STYLE_LIST"

# Build the items.json manifest.  "file" must point at the path used inside the
# archive, otherwise OsmAnd cannot match the manifest entry with the ZIP entry.
{
	printf '{"version":%s,"items":[' "$MANIFEST_VERSION"
	separator=""
	for file in "$PKG_DIR"/rendering/*.render.xml; do
		[ -f "$file" ] || continue
		printf '%s{"type":"FILE","subtype":"rendering_style","file":"rendering/%s"}' \
			"$separator" "$(basename "$file")"
		separator=","
	done
	printf ']}\n'
} > "$PKG_DIR/items.json"

case "$OUT_FILE" in
	/*) OUT_ABS="$OUT_FILE" ;;
	*) OUT_ABS="$(pwd)/$OUT_FILE" ;;
esac
mkdir -p "$(dirname "$OUT_ABS")"

rm -f "$OUT_ABS"
(cd "$PKG_DIR" && zip -q -r "$OUT_ABS" items.json rendering)

echo "Built $OUT_ABS"
if command -v unzip >/dev/null 2>&1; then
	unzip -l "$OUT_ABS" | sed 's/^/  /'
fi
