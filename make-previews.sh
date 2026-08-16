#!/usr/bin/env zsh
# Regenerate all preview images, two tiers per shot:
#   previews/      fast OpenSCAD renders (flat shading) — for iteration
#   previews/hd/   same piece, same angle, same size — F3D PBR render of a
#                  per-shot GLB (walnut body + metallic gold ornament)
#
# Camera mapping: an OpenSCAD --camera=0,0,0,RX,0,RZ,0 view direction equals
# -(Rz(RZ)*Rx(RX)*[0,0,1]), passed to f3d as --camera-direction. Both tiers
# auto-fit the model, so framing matches.
set -euo pipefail
cd "$(dirname "$0")"

SCAD=parametric-picture-frame.scad
mkdir -p previews/hd

# name | WxH | osc rx,rz | scad -D args (; separated) | groups: 2=body+ornament, 1=body only
SHOTS=(
  'assembled_iso|1600x1200|55,25|render_mode="assembled"|2'
  'assembled_top|1400x1000|0,0|render_mode="assembled"|2'
  'exploded_iso|1600x1200|55,25|render_mode="exploded"|2'
  'corner_bl_iso|1200x900|55,25|render_mode="part";part_kind="corner"|2'
  'corner_bl_back|1200x900|235,25|render_mode="part";part_kind="corner"|2'
  'part_b2_iso|1200x900|55,25|render_mode="part";part_index=2|2'
  'style_revogee|1200x900|55,25|render_mode="part";part_index=2;profile_style="reverse_ogee"|2'
  'style_ripple|1200x900|55,25|render_mode="part";part_index=2;profile_style="ripple"|2'
  'clips_iso|1000x750|55,25|render_mode="clips"|1'
  'fit_iso|1000x750|55,25|render_mode="fit_test"|1'
)

for shot in "${SHOTS[@]}"; do
  IFS='|' read -r name size cam args groups <<< "$shot"
  defines=()
  for a in "${(s:;:)args}"; do defines+=(-D "$a"); done
  rx="${cam%,*}" rz="${cam#*,}"

  echo "== $name"
  openscad --backend=Manifold --camera="0,0,0,$rx,0,$rz,0" --imgsize="${size/x/,}" \
    --colorscheme="Tomorrow Night" --autocenter --viewall \
    "${defines[@]}" -o "previews/$name.png" "$SCAD" 2>/dev/null

  openscad --backend=Manifold "${defines[@]}" -D 'export_group="body"' \
    -o /tmp/shot_body.stl "$SCAD" 2>/dev/null
  orn=-
  if [[ $groups == 2 ]]; then
    orn=/tmp/shot_ornament.stl
    openscad --backend=Manifold "${defines[@]}" -D 'export_group="ornament"' \
      -o "$orn" "$SCAD" 2>/dev/null
  fi
  uv run --quiet make-glb.py /tmp/shot_body.stl "$orn" /tmp/shot.glb

  # match the OpenSCAD camera: direction = -(Rz(rz)*Rx(rx)*ez), up = Rz*Rx*ey.
  # BOTH must be passed — without the up vector f3d rolls the view.
  read -r dir up <<< "$(python3 -c "
import math
rx, rz = math.radians($rx), math.radians($rz)
def rot(v):
    x, y, z = v
    y, z = y*math.cos(rx) - z*math.sin(rx), y*math.sin(rx) + z*math.cos(rx)
    x, y = x*math.cos(rz) - y*math.sin(rz), x*math.sin(rz) + y*math.cos(rz)
    return x, y, z
e, u = rot((0, 0, 1)), rot((0, 1, 0))
print(f'{-e[0]:.4f},{-e[1]:.4f},{-e[2]:.4f} {u[0]:.4f},{u[1]:.4f},{u[2]:.4f}')")"
  f3d /tmp/shot.glb --no-config --output "previews/hd/$name.png" \
    --resolution "${size/x/,}" --ambient-occlusion --tone-mapping \
    --anti-aliasing-mode ssaa --hdri-ambient --light-intensity 2.3 \
    --background-color 0.10,0.10,0.11 \
    --camera-direction="$dir" --camera-view-up="$up" \
    2>/dev/null | grep -v deprecated || true
done

echo "Done: ${#SHOTS[@]} shots in previews/ and previews/hd/"
