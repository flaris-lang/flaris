#!/bin/sh
# Regenerates the TIFF fixtures that tests/test_tiff.fls decodes. They are
# written by libtiff's own tools, so the decoder is checked against an
# independent encoder rather than only against Tiff.fls's.
#
# Needs libtiff's tools (raw2tiff, tiffcp, tiffset, ppm2tiff) and flarisvm.
#   VM=/path/to/flarisvm sh tests/tiff/make_fixtures.sh
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
VM="${VM:-flarisvm}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cd "$TMP"
"$VM" "$HERE/mkraw.fls"

O="$HERE"
R="-M -w 37 -l 23"          # -M: FillOrder 1 (MSB first), the normal case

# 8-bit RGB through every codec, strip and tile layout, byte order and format.
raw2tiff $R -b 3 -p rgb -c none -r 5 rgb8.raw "$O/rgb8_none_strips.tif"
raw2tiff $R -b 3 -p rgb -c lzw -r 8  rgb8.raw "$O/rgb8_lzw.tif"
raw2tiff $R -b 3 -p rgb -c lzw:2     rgb8.raw "$O/rgb8_lzw_pred.tif"
raw2tiff $R -b 3 -p rgb -c zip:2     rgb8.raw "$O/rgb8_zip_pred.tif"
raw2tiff $R -b 3 -p rgb -c packbits  rgb8.raw "$O/rgb8_packbits.tif"
raw2tiff $R -b 3 -p rgb -c jpeg      rgb8.raw "$O/rgb8_jpeg.tif"
raw2tiff -L -w 37 -l 23 -b 3 -p rgb -c lzw:2 rgb8.raw "$O/rgb8_fill2_lzw_pred.tif"
tiffcp -t -w 16 -l 16 -c lzw                "$O/rgb8_none_strips.tif" "$O/rgb8_tiled_lzw.tif"
tiffcp -t -w 16 -l 16 -c zip:2 -p separate  "$O/rgb8_none_strips.tif" "$O/rgb8_tiled_planar_zip.tif"
tiffcp -p separate -c lzw:2                 "$O/rgb8_none_strips.tif" "$O/rgb8_planar_lzw_pred.tif"
tiffcp -B -c zip                            "$O/rgb8_none_strips.tif" "$O/rgb8_be_zip.tif"
tiffcp -8 -c lzw:2                          "$O/rgb8_none_strips.tif" "$O/rgb8_bigtiff_lzw.tif"
tiffcp -8 -B -t -w 16 -l 16 -c packbits     "$O/rgb8_none_strips.tif" "$O/rgb8_bigtiff_be_tiled.tif"

# 16-bit samples, horizontal predictor in both byte orders.
raw2tiff $R -b 3 -d short -p rgb -c zip:2 rgb16le.raw "$O/rgb16_le_zip_pred.tif"
raw2tiff $R -b 1 -d short -p minisblack -c none gray16le.raw g16.tif
tiffcp -B -c lzw:2 g16.tif "$O/gray16_be_lzw_pred.tif"

# Alpha: no ExtraSamples tag (not alpha), unassociated, associated.
raw2tiff $R -b 4 -p rgb -c lzw:2 rgba8.raw "$O/rgba8_noextra_lzw_pred.tif"
raw2tiff $R -b 4 -p rgb -c lzw:2 rgba8.raw "$O/rgba8_unassoc_lzw_pred.tif"
tiffset -s 338 1 2 "$O/rgba8_unassoc_lzw_pred.tif"
raw2tiff $R -b 4 -p rgb -c lzw rgba8_premul.raw "$O/rgba8_assoc_lzw.tif"
tiffset -s 338 1 1 "$O/rgba8_assoc_lzw.tif"

# Grayscale, bilevel, palette, CMYK.
raw2tiff $R -b 1 -p minisblack -c packbits gray8.raw "$O/gray8_packbits.tif"
raw2tiff $R -b 1 -p miniswhite -c none     gray8.raw "$O/gray8_white_none.tif"
tiffcp -c lzw gray4.tif "$O/gray4_lzw.tif"
cp gray2_none.tif "$O/gray2_none.tif"
ppm2tiff -c packbits bits.pbm "$O/bits1_packbits.tif"
tiffcp -c lzw pal8.tif "$O/pal8_lzw.tif"
tiffcp -c packbits pal4.tif "$O/pal4_packbits.tif"
cp pal8_cmap8_none.tif "$O/pal8_cmap8_none.tif"
raw2tiff $R -b 4 -p cmyk -c lzw cmyk8.raw "$O/cmyk8_lzw.tif"

# LZW past 4094 codes: 12-bit codes and a table reset.
raw2tiff -M -w 64 -l 40 -b 3 -p rgb -c lzw -r 40 big8.raw "$O/big8_lzw.tif"

# Three pages, three formats.
tiffcp "$O/rgb8_lzw_pred.tif" "$O/gray8_packbits.tif" "$O/pal8_lzw.tif" "$O/multi3.tif"

echo "fixtures written to $O"
