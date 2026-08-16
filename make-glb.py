# /// script
# requires-python = ">=3.10"
# dependencies = ["trimesh", "numpy"]
# ///
# Pack the body + ornament STL exports into one GLB with PBR materials,
# for viewers with real lighting (e.g. https://f3d.app/viewer).
#
# Usage:
#   openscad --backend=Manifold -D 'render_mode="assembled"' -D 'export_group="body"' \
#     -o /tmp/frame_body.stl parametric-picture-frame.scad
#   openscad --backend=Manifold -D 'render_mode="assembled"' -D 'export_group="ornament"' \
#     -o /tmp/frame_ornament.stl parametric-picture-frame.scad
#   uv run make-glb.py

import numpy as np  # noqa: F401 — kept for uv script deps
import trimesh


# glTF baseColorFactor is linear, not sRGB — feeding sRGB washes colors out
def srgb_to_linear(rgb):
    return [((c + 0.055) / 1.055) ** 2.4 if c > 0.04045 else c / 12.92 for c in rgb] + [1.0]


# The frame lies in the XY plane with its face along +Z — in glTF (Y-up,
# +Z toward the viewer) that is already "hanging on the wall, facing you".
WALNUT = trimesh.visual.material.PBRMaterial(
    name="walnut", baseColorFactor=srgb_to_linear([0.26, 0.16, 0.06]),
    metallicFactor=0.0, roughnessFactor=0.65)
GOLD = trimesh.visual.material.PBRMaterial(
    name="gold", baseColorFactor=srgb_to_linear([0.83, 0.66, 0.26]),
    metallicFactor=1.0, roughnessFactor=0.35)

scene = trimesh.Scene()
for path, name, mat in [("/tmp/frame_body.stl", "body", WALNUT),
                        ("/tmp/frame_ornament.stl", "ornament", GOLD)]:
    mesh = trimesh.load(path)
    mesh.visual = trimesh.visual.TextureVisuals(material=mat)
    scene.add_geometry(mesh, node_name=name, geom_name=name)

out = "parametric-picture-frame.glb"
scene.export(out)
print(out, f"{len(scene.geometry)} meshes,",
      sum(len(g.faces) for g in scene.geometry.values()), "triangles")
