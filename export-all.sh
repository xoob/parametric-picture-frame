#!/usr/bin/env zsh
# Export every frame part, the clips plate and the dovetail fit-test coupon
# as STL into stl/, ready to drag into Bambu Studio.
#
# Usage: ./export-all.sh [shrinkage_compensation]
#   e.g. ./export-all.sh 1.003   # +0.3% XY compensation, measured via fit_test
set -euo pipefail
cd "$(dirname "$0")"

SHRINK="${1:-1.0}"
SCAD=parametric-picture-frame.scad
OUT=stl
BOM=/tmp/frame_bom.echo
mkdir -p "$OUT"

os() {
  openscad --backend=Manifold -D "shrinkage_compensation=$SHRINK" "$@" "$SCAD"
}

# segment counts come from the model itself (echoed as: COUNTS <bottom/top> <left/right>)
openscad --backend=Manifold -D 'render_mode="bom"' -o "$BOM" "$SCAD"
read -r NH NV <<< "$(grep -o 'COUNTS [0-9]* [0-9]*' "$BOM" | awk '{print $2, $3}')"
echo "Segments per leg: bottom/top $NH, left/right $NV (shrink factor $SHRINK)"

for leg in bottom right top left; do
  case $leg in
    bottom) code=BL; letter=B; n=$NH ;;
    right)  code=BR; letter=R; n=$NV ;;
    top)    code=TR; letter=T; n=$NH ;;
    left)   code=TL; letter=L; n=$NV ;;
  esac
  echo "corner_$code"
  os -D 'render_mode="part"' -D 'part_kind="corner"' -D "part_leg=\"$leg\"" \
     -o "$OUT/corner_$code.stl"
  for i in $(seq 1 "$n"); do
    echo "$letter$i"
    os -D 'render_mode="part"' -D 'part_kind="straight"' -D "part_leg=\"$leg\"" \
       -D "part_index=$i" -o "$OUT/$letter$i.stl"
  done
done

echo "clips"
os -D 'render_mode="clips"' -o "$OUT/clips.stl"
echo "fit_test"
os -D 'render_mode="fit_test"' -o "$OUT/fit_test.stl"

echo "Done: $(ls "$OUT" | wc -l | tr -d ' ') STL files in $OUT/"
