// lib/profiles.scad — cross-section (Querschnitt) generators
//
// Trade anatomy (framedestination.com, "Understanding Picture Frame Profiles"):
// face = decorative front width, height = wall-to-tallest-point, lip = inner
// edge overlapping the art, rabbet = pocket holding the art, heel = outer back
// edge. Style mapping: ogee ~ "Swan" (ornate traditional), reverse_ogee ~
// "Reverse Scoop" (rises away from the art), ripple ~ "Stepped".
//
// Coordinates: u = distance from the sight (inner) edge, z = height above the
// back plane. Curves are defined as control point lists [u_frac, z_frac, shape]
// where u_frac is a fraction of face_w, z_frac a fraction of profile_h, and
// shape describes the segment ENDING at that point: 0 = straight line,
// 1 = cosine ease (smooth blend). The curve is single-valued in u, so steep or
// vertical steps are fine (walls, not overhangs) — exaggerated massing prints.

function _ease(t) = (1 - cos(180 * t)) / 2;

// per-style massing: how tall the silhouette is relative to the face width
function prof_h_ratio(style) =
  style == "ogee" ? 0.52 : style == "reverse_ogee" ? 0.55 : 0.42;

function prof_curve(style) =
  style == "ogee" ? [
    // reference 1: rounded sight lip into ONE dominant tall inner roll,
    // steep fall into a wide sunken gold channel, modest outer rail
    [0.00, 0.70, 0],
    [0.02, 0.78, 1],
    [0.055, 0.84, 1],
    [0.08, 0.84, 0],
    [0.11, 0.96, 1],
    [0.17, 1.00, 1],
    [0.24, 0.96, 1],
    [0.28, 0.72, 1],
    [0.30, 0.46, 0],
    [0.33, 0.44, 1],
    [0.72, 0.44, 0],
    [0.75, 0.52, 1],
    [0.78, 0.56, 1],
    [0.85, 0.56, 0],
    [0.88, 0.48, 1],
    [1.00, 0.44, 0],
  ] :
  style == "reverse_ogee" ? [
    // reference 2: low gold bead step near the glass, shadow groove, one long
    // crown sweep rising outward to a high plateau and outer crest ridge
    [0.00, 0.63, 0],
    [0.03, 0.69, 1],
    [0.14, 0.69, 0],
    [0.17, 0.61, 1],
    [0.22, 0.66, 1],
    [0.42, 0.97, 1],
    [0.48, 1.00, 1],
    [0.68, 1.00, 0],
    [0.74, 0.94, 1],
    [0.78, 0.60, 0],
    [0.82, 0.52, 1],
    [0.92, 0.52, 0],
    [0.95, 0.56, 1],
    [1.00, 0.48, 1],
  ] :
  style == "ripple" ? [
    // reference 3: symmetric ribbed pyramid — flat-topped ribs climbing to a
    // central crest, then descending ribs and clean roundovers to the edge
    [0.00, 0.84, 0],
    [0.03, 0.90, 1],
    [0.15, 0.90, 0],
    [0.175, 0.74, 0],
    [0.20, 0.74, 0],
    [0.225, 0.96, 0],
    [0.31, 0.96, 0],
    [0.335, 0.78, 0],
    [0.36, 0.78, 0],
    [0.385, 1.00, 0],
    [0.475, 1.00, 0],
    [0.50, 0.80, 0],
    [0.525, 0.80, 0],
    [0.55, 0.94, 0],
    [0.62, 0.94, 0],
    [0.645, 0.76, 0],
    [0.67, 0.76, 0],
    [0.695, 0.88, 0],
    [0.755, 0.88, 0],
    [0.78, 0.66, 0],
    [0.86, 0.66, 0],
    [0.92, 0.56, 1],
    [1.00, 0.48, 1],
  ] :
  assert(false, str("unknown profile_style: ", style)) [];

// Ornament bands: [u1, u2, z_frac, motif, color_role, mode]
// motif: 0 scroll, 1 acanthus, 2 egg&dart, 3 meander
// color_role: 0 body, 1 gold | mode: 0 relief, 1 engrave
function prof_bands(style) =
  style == "ogee"         ? [[0.33, 0.72, 0.44, 0, 1, 0]] :
  style == "reverse_ogee" ? [[0.48, 0.68, 1.00, 1, 0, 0],
                             [0.03, 0.14, 0.69, 2, 1, 0]] :
                            [[0.225, 0.31, 0.96, 3, 0, 1],
                             [0.385, 0.475, 1.00, 3, 0, 1]];

function _segz(C, s, t) =
  let(z1 = C[s][1], z2 = C[s + 1][1], ty = C[s + 1][2])
  z1 + (z2 - z1) * (ty == 0 ? t : _ease(t));

// z_frac of the top surface at u_frac (clamped to [0,1])
function prof_z(C, uf) =
  let(cl = min(max(uf, 0), 1),
      s = [for (i = [0:len(C) - 2]) if (cl >= C[i][0] && cl <= C[i + 1][0]) i][0],
      t = (cl - C[s][0]) / max(C[s + 1][0] - C[s][0], 1e-9))
  _segz(C, s, t);

// minimum z_frac over [uf1, uf2]
function prof_min_z(C, uf1, uf2, n = 48) =
  min([for (i = [0:n]) prof_z(C, uf1 + (uf2 - uf1) * i / n)]);

// Full closed cross-section polygon in leg-local coordinates:
// x = y_local = face_w - u (outer edge at 0, sight edge at face_w), y = z.
// Includes the rear rabbet notch under the lip.
function leg_xsec_pts(C, fw, H, lipw, rd, step) =
  let(top = [for (s = [0:len(C) - 2]) each
              let(u1 = C[s][0], u2 = C[s + 1][0],
                  n = max(2, ceil((u2 - u1) * fw / step)))
              [for (j = [(s == 0 ? 0 : 1):n])
                let(t = j / n, uf = u1 + (u2 - u1) * t)
                [fw - uf * fw, H * _segz(C, s, t)]]])
  concat([[fw, rd]], top, [[0, 0], [fw - lipw, 0], [fw - lipw, rd]]);
