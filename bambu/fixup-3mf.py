# Post-process the CLI-exported Bambu Studio project 3mf.
#
# The CLI's --arrange both drifts content toward the plate boundary and builds
# invalid pairings, so we own the plating end-to-end instead:
#
#   replate:  regroup objects onto plates (greedy geometric pairing, stacked
#             along y with a 2 mm gap), place them centered, rewrite plate
#             membership and item transforms. Keeps input (= assembly) order.
#   verify:   assert every object's true mesh bbox lies inside its plate.
#   metadata: filament display color (Matte Black; GUI defaults to green) +
#             different_settings_to_system so process overrides show orange.
#
# Plate grid per BambuStudio source (PartPlate.cpp/.hpp): plate k sits at
# (col * 1.2 * bed, -row * 1.2 * bed), cols = compute_colum_count(n) which is
# round(sqrt(n)) rounded up when sqrt(n) has a fraction above .5-rounding.
import json
import math
import re
import shutil
import sys
import zipfile

BED = 180.0
STRIDE = BED * 1.2
CENTER = BED / 2
GAP = 2.0
MARGIN = 1.0  # printable-edge slack for the in-bounds check

mode, out = sys.argv[1], sys.argv[2]


def colum_count(n):
    r = round(math.sqrt(n))
    return r + 1 if math.sqrt(n) > r else r


def read_zip(path):
    with zipfile.ZipFile(path) as z:
        return {n: z.read(n) for n in z.namelist()}


def write_zip(path, entries):
    tmp = path + ".tmp"
    with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as z:
        for name, data in entries.items():
            z.writestr(name, data)
    shutil.move(tmp, path)


def parse(entries):
    root = entries["3D/3dmodel.model"].decode()
    items = [(m.group(1), [float(x) for x in m.group(2).split()])
             for m in re.finditer(r'<item objectid="(\d+)"[^>]*transform="([^"]+)"', root)]
    bbox = {}
    for m in re.finditer(
            r'<object id="(\d+)"[^>]*>\s*<components>\s*<component[^>]*p:path="([^"]+)"[^>]*transform="([^"]+)"',
            root):
        oid, path, tr = m.groups()
        v = [float(x) for x in tr.split()]
        assert v[:9] == [1, 0, 0, 0, 1, 0, 0, 0, 1], f"rotated component in object {oid}"
        xs, ys = [], []
        for vm in re.finditer(r'<vertex x="([-0-9.e]+)" y="([-0-9.e]+)"', entries[path.lstrip("/")].decode()):
            xs.append(float(vm.group(1)))
            ys.append(float(vm.group(2)))
        bbox[oid] = (min(xs) + v[9], max(xs) + v[9], min(ys) + v[10], max(ys) + v[10])
    return root, items, bbox


def size(b):
    return b[1] - b[0], b[3] - b[2]


entries = read_zip(out)

if mode == "replate":
    root, items, bbox = parse(entries)
    # the CLI reorders build items (corners first), so recover the assembly
    # order from the object names: BL, B1.., BR, R1.., TR, T<n>..T1, TL, L<n>..L1, clips
    names = {m.group(2).removesuffix(".stl"): m.group(1)
             for m in re.finditer(
                 r'<object id="(\d+)">\s*<metadata key="name" value="([^"]+)"',
                 entries["Metadata/model_settings.config"].decode())}
    nh = max(int(n[1:]) for n in names if re.fullmatch(r"B\d+", n))
    nv = max(int(n[1:]) for n in names if re.fullmatch(r"R\d+", n))
    seq = (["corner_BL"] + [f"B{i}" for i in range(1, nh + 1)] + ["corner_BR"]
           + [f"R{i}" for i in range(1, nv + 1)] + ["corner_TR"]
           + [f"T{i}" for i in range(nh, 0, -1)] + ["corner_TL"]
           + [f"L{i}" for i in range(nv, 0, -1)] + ["clips"])
    assert set(seq) == set(names), f"part names mismatch: {set(seq) ^ set(names)}"
    order = [names[n] for n in seq]

    # greedy pairing in assembly order: two consecutive objects share a plate
    # when stacked along y (widths and depth sum must fit the bed)
    plates, i = [], 0
    while i < len(order):
        a = order[i]
        if i + 1 < len(order):
            b = order[i + 1]
            (wa, da), (wb, db) = size(bbox[a]), size(bbox[b])
            if max(wa, wb) <= BED - 2 * MARGIN and da + GAP + db <= BED - 2 * MARGIN:
                plates.append([a, b])
                i += 2
                continue
        plates.append([a])
        i += 1

    cols = colum_count(len(plates))
    pos = {}
    for k, oids in enumerate(plates):
        ox, oy = (k % cols) * STRIDE, -(k // cols) * STRIDE
        depths = [size(bbox[o])[1] for o in oids]
        total = sum(depths) + GAP * (len(oids) - 1)
        y = CENTER - total / 2
        for o, d in zip(oids, depths):
            cx, cy = (bbox[o][0] + bbox[o][1]) / 2, (bbox[o][2] + bbox[o][3]) / 2
            pos[o] = (ox + CENTER - cx, oy + y + d / 2 - cy)
            y += d + GAP

    def place(m):
        v = m.group(2).split()
        p = pos[m.group(1)]
        v[9], v[10] = f"{p[0]:.6f}", f"{p[1]:.6f}"
        return m.group(0).replace(m.group(2), " ".join(v))

    entries["3D/3dmodel.model"] = re.sub(
        r'<item objectid="(\d+)"[^>]*transform="([^"]+)"', place, root).encode()

    # rebuild plate membership with fresh unique identify_ids
    ms = entries["Metadata/model_settings.config"].decode()
    ident = {o: str(200 + i) for i, o in enumerate(order)}
    xml = []
    for k, oids in enumerate(plates, 1):
        inst = "\n".join(
            f'    <model_instance>\n      <metadata key="object_id" value="{o}"/>\n'
            f'      <metadata key="instance_id" value="0"/>\n'
            f'      <metadata key="identify_id" value="{ident[o]}"/>\n    </model_instance>'
            for o in oids)
        # no thumbnail_file: previews would show a stale layout; the GUI copes
        xml.append(
            f'  <plate>\n    <metadata key="plater_id" value="{k}"/>\n'
            f'    <metadata key="plater_name" value=""/>\n'
            f'    <metadata key="locked" value="false"/>\n'
            f'    <metadata key="filament_map_mode" value="Auto For Flush"/>\n{inst}\n  </plate>')
    ms = re.sub(r"[ \t]*<plate>.*</plate>", "\n".join(xml), ms, flags=re.S)
    entries["Metadata/model_settings.config"] = ms.encode()

    # drop stale thumbnails; the CLI round-trip regenerates them
    entries = {n: d for n, d in entries.items()
               if not re.match(r"Metadata/(plate|plate_no_light|top|pick)_\d+", n)}
    print(f"replate: {len(order)} objects on {len(plates)} plates ({cols} cols)")

elif mode == "verify":
    root, items, bbox = parse(entries)
    ms = entries["Metadata/model_settings.config"].decode()
    plates = [re.findall(r'"object_id" value="(\d+)"', p)
              for p in re.findall(r"<plate>(.*?)</plate>", ms, re.S)]
    t = dict(items)
    n = 0
    for oids in plates:
        for o in oids:
            gx = (bbox[o][0] + bbox[o][1]) / 2 + t[o][9]
            gy = (bbox[o][2] + bbox[o][3]) / 2 + t[o][10]
            # snap to the nearest plate CENTER (grid origins + 90): any object
            # inside a plate is within +-90 of it, so this is unambiguous
            ox = max(0, round((gx - CENTER) / STRIDE)) * STRIDE
            oy = -max(0, round((CENTER - gy) / STRIDE)) * STRIDE
            w, d = size(bbox[o])
            for lo, hi in [(gx - ox - w / 2, gx - ox + w / 2), (gy - oy - d / 2, gy - oy + d / 2)]:
                assert -0.1 <= lo and hi <= BED + 0.1, \
                    f"object {o} exceeds plate: [{lo:.1f}, {hi:.1f}] of {BED}"
            n += 1
    print(f"verify: {n} objects within their plates")

elif mode == "metadata":
    meta = {"type", "from", "version", "inherits", "name", "print_settings_id", "compatible_printers"}
    overrides = ";".join(sorted(set(json.load(open("bambu/overrides.json"))) - meta))
    cfg = json.loads(entries["Metadata/project_settings.config"])
    cfg["different_settings_to_system"] = [overrides, "", ""]
    cfg["filament_colour"] = ["#000000"]
    entries["Metadata/project_settings.config"] = json.dumps(cfg, indent=4).encode()
    print(f"metadata: filament #000000, modified-from-system: {overrides}")

else:
    raise SystemExit(f"unknown mode {mode}")

if mode != "verify":
    write_zip(out, entries)
