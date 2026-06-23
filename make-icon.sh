#!/bin/bash
# Generates the macOS AppIcon PNGs for Aries from aries-icon.svg.
# Run from the repo root: bash make-icon.sh
set -e

SVG="aries-icon.svg"
OUT="Valentine/Assets.xcassets/AppIcon.appiconset"

if [ ! -f "$SVG" ]; then
    echo "Error: $SVG not found. Run this from the repo root."
    exit 1
fi

mkdir -p "$OUT"

# Rasterize the SVG to a 1024 master. `qlmanage` ships with macOS and renders SVG.
# If you have rsvg-convert or Inkscape, those work too — but this needs no installs.
render() {
    local size=$1 file=$2
    # Try qlmanage (built in). Falls back to sips if a PNG master exists.
    qlmanage -t -s "$size" -o /tmp "$SVG" >/dev/null 2>&1
    mv "/tmp/$(basename "$SVG").png" "$OUT/$file"
}

# macOS icon sizes (pt @ scale -> px)
render 16   "icon_16.png"
render 32   "icon_16@2x.png"
render 32   "icon_32.png"
render 64   "icon_32@2x.png"
render 128  "icon_128.png"
render 256  "icon_128@2x.png"
render 256  "icon_256.png"
render 512  "icon_256@2x.png"
render 512  "icon_512.png"
render 1024 "icon_512@2x.png"

# Write the Contents.json that maps the files to slots.
cat > "$OUT/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "icon_16.png",     "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16@2x.png",  "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32.png",     "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32@2x.png",  "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128.png",    "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256.png",    "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512.png",    "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

echo "Done. Icons written to $OUT"
echo "If icons look wrong, qlmanage's SVG render is imperfect — install librsvg (brew install librsvg) and replace the render() body with: rsvg-convert -w \$size -h \$size \"\$SVG\" -o \"\$OUT/\$file\""
