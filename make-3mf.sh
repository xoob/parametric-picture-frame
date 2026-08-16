#!/usr/bin/env zsh
# Build one multi-plate Bambu Studio project 3mf from all frame parts, with
# machine/process/filament configured and our overrides (lightning infill,
# 2 walls, no supports) bundled as orange "modified" fields on the system
# process preset. The project is NOT sliced — review and slice in the GUI.
#
# Usage: ./make-3mf.sh [shrinkage_compensation]
# Env:   BASE_PROCESS  system process preset to inherit (default 0.42mm Extra Draft)
set -euo pipefail
cd "$(dirname "$0")"

BS="/Applications/BambuStudio.app/Contents/MacOS/BambuStudio"
SYS="$HOME/Library/Application Support/BambuStudio/system/BBL"
BASE_PROCESS="${BASE_PROCESS:-0.42mm Extra Draft @BBL A1M 0.6 nozzle}"
MACHINE="Bambu Lab A1 mini 0.6 nozzle"
FILAMENT="Bambu PLA Matte @BBL A1M"
OUT=parametric-picture-frame.3mf

./export-all.sh "${1:-1.0}"

# wire the sparse override JSON to the chosen base preset
PROCESS_JSON=$(mktemp -t process-frame).json
python3 - "$BASE_PROCESS" "$MACHINE" "$PROCESS_JSON" <<'EOF'
import json, sys
base, machine, out = sys.argv[1:4]
p = json.load(open("bambu/process-frame.json"))
p |= {"inherits": base, "name": base, "print_settings_id": base,
      "compatible_printers": [machine]}
json.dump(p, open(out, "w"), indent=2)
EOF

# parts in assembly/print order (segment counts from the model's BOM echo)
read -r NH NV <<< "$(grep -o 'COUNTS [0-9]* [0-9]*' /tmp/frame_bom.echo | awk '{print $2, $3}')"
parts=(corner_BL)
for i in $(seq 1 "$NH"); do parts+=("B$i"); done
parts+=(corner_BR)
for i in $(seq 1 "$NV"); do parts+=("R$i"); done
parts+=(corner_TR)
for i in $(seq "$NH" -1 1); do parts+=("T$i"); done
parts+=(corner_TL)
for i in $(seq "$NV" -1 1); do parts+=("L$i"); done
parts+=(clips)
files=()
for p in "${parts[@]}"; do files+=("stl/$p.stl"); done

"$BS" "${files[@]}" \
  --load-settings "$SYS/machine/$MACHINE.json;$PROCESS_JSON" \
  --load-filaments "$SYS/filament/$FILAMENT.json" \
  --arrange 1 --orient 0 --ensure-on-bed \
  --export-3mf "$OUT" --outputdir "$PWD"  # must be absolute, "." goes nowhere

# The CLI leaves different_settings_to_system empty; fill it so Bambu Studio
# shows our overrides as orange (modified) fields on the system preset.
python3 - "$OUT" <<'EOF'
import json, shutil, sys, zipfile
out = sys.argv[1]
meta = {"type", "from", "version", "inherits", "name", "print_settings_id", "compatible_printers"}
overrides = ";".join(sorted(set(json.load(open("bambu/process-frame.json"))) - meta))
cfg_path = "Metadata/project_settings.config"
tmp = out + ".tmp"
with zipfile.ZipFile(out) as zin, zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zout:
    for item in zin.infolist():
        data = zin.read(item.filename)
        if item.filename == cfg_path:
            cfg = json.loads(data)
            cfg["different_settings_to_system"] = [overrides, "", ""]
            data = json.dumps(cfg, indent=4).encode()
        zout.writestr(item, data)
shutil.move(tmp, out)
print(f"{out}: marked as modified-from-system: {overrides}")
EOF

plates=$(unzip -l "$OUT" | grep -c 'plate_[0-9]*_small.png')
echo "Done: $OUT (${#parts[@]} parts, $plates plates, base process: $BASE_PROCESS)"
