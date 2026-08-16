// lib/profiles.scad — cross-section (Querschnitt) generators
//
// Coordinates: u = distance from the sight (inner) edge, z = height above the
// back plane. Curves are defined as control point lists [u_frac, z_frac, shape]
// where u_frac is a fraction of face_w, z_frac a fraction of profile_h, and
// shape describes the segment ENDING at that point: 0 = straight line,
// 1 = cosine ease (smooth blend). All slopes stay <= ~50 deg from horizontal so
// the decorative face prints face-up without supports.

function _ease(t) = (1 - cos(180 * t)) / 2;

// per-style massing: how tall the silhouette is relative to the face width
function prof_h_ratio(style) =
  style == "ogee" ? 0.52 : style == "reverse_ogee" ? 0.55 : 0.42;

function prof_curve(style) =
  style == "ogee" ? [
    // reference 1: rounded sight lip into ONE dominant tall inner roll,
    // steep fall into a wide sunken gold channel, modest outer rail
    [0.00, 0.68, 0],
    [0.05, 0.76, 1],
    [0.09, 0.82, 1],
    [0.19, 1.00, 1],
    [0.29, 1.00, 0],
    [0.39, 0.76, 1],
    [0.46, 0.62, 1],
    [0.50, 0.60, 1],
    [0.74, 0.60, 0],
    [0.78, 0.65, 1],
    [0.88, 0.66, 0],
    [0.94, 0.62, 1],
    [1.00, 0.52, 1],
  ] :
  style == "reverse_ogee" ? [
    // reference 2: low gold bead step near the glass, shadow groove, one long
    // crown sweep rising outward to a high plateau and outer crest ridge
    [0.00, 0.64, 0],
    [0.04, 0.70, 1],
    [0.16, 0.70, 0],
    [0.20, 0.63, 1],
    [0.30, 0.72, 1],
    [0.46, 0.92, 1],
    [0.50, 0.92, 0],
    [0.74, 0.92, 0],
    [0.80, 1.00, 1],
    [0.86, 0.94, 1],
    [0.94, 0.76, 1],
    [1.00, 0.60, 1],
  ] :
  style == "ripple" ? [
    // reference 3: symmetric ribbed pyramid — flat-topped ribs climbing to a
    // central crest, then descending ribs and clean roundovers to the edge
    [0.00, 0.82, 0],
    [0.03, 0.88, 1],
    [0.15, 0.88, 0],
    [0.205, 0.79, 1],
    [0.26, 0.94, 1],
    [0.32, 0.94, 0],
    [0.375, 0.84, 1],
    [0.43, 1.00, 1],
    [0.53, 1.00, 0],
    [0.585, 0.86, 1],
    [0.64, 0.92, 1],
    [0.70, 0.92, 0],
    [0.755, 0.78, 1],
    [0.81, 0.84, 1],
    [0.86, 0.84, 0],
    [0.93, 0.66, 1],
    [1.00, 0.54, 1],
  ] :
  assert(false, str("unknown profile_style: ", style)) [];

// Ornament bands: [u1, u2, z_frac, motif, color_role, mode]
// motif: 0 scroll, 1 acanthus, 2 egg&dart, 3 meander
// color_role: 0 body, 1 gold | mode: 0 relief, 1 engrave
function prof_bands(style) =
  style == "ogee"         ? [[0.50, 0.74, 0.60, 0, 1, 0]] :
  style == "reverse_ogee" ? [[0.50, 0.74, 0.92, 1, 0, 0],
                             [0.06, 0.16, 0.70, 2, 1, 0]] :
                            [[0.26, 0.32, 0.94, 3, 0, 1],
                             [0.43, 0.53, 1.00, 3, 0, 1]];

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
