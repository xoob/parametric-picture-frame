// lib/profiles.scad — cross-section (Querschnitt) generators
//
// Coordinates: u = distance from the sight (inner) edge, z = height above the
// back plane. Curves are defined as control point lists [u_frac, z_frac, shape]
// where u_frac is a fraction of face_w, z_frac a fraction of profile_h, and
// shape describes the segment ENDING at that point: 0 = straight line,
// 1 = cosine ease (smooth blend). All slopes stay <= ~50 deg from horizontal so
// the decorative face prints face-up without supports.

function _ease(t) = (1 - cos(180 * t)) / 2;

function prof_curve(style) =
  style == "ogee" ? [
    // sight fillet, inner scallop band, deep cove, grand ogee rise,
    // wide scroll band, groove, outer bead, outer fall
    [0.00, 0.80, 0],
    [0.04, 0.84, 1],
    [0.17, 0.84, 0],
    [0.26, 0.60, 1],
    [0.54, 0.97, 1],
    [0.80, 0.97, 0],
    [0.83, 0.89, 1],
    [0.87, 0.96, 1],
    [0.91, 0.87, 1],
    [1.00, 0.75, 1],
  ] :
  style == "reverse_ogee" ? [
    // high inner crest with band, grand fall outward, low outer scroll band,
    // outer bead
    [0.00, 0.80, 0],
    [0.06, 0.94, 1],
    [0.20, 0.94, 0],
    [0.46, 0.60, 1],
    [0.60, 0.66, 1],
    [0.84, 0.66, 0],
    [0.88, 0.74, 1],
    [0.93, 0.62, 1],
    [1.00, 0.55, 1],
  ] :
  style == "ripple" ? [
    // inner band, three rising ripples (Wellenleiste), outer scroll band, bead
    [0.00, 0.80, 0],
    [0.04, 0.86, 1],
    [0.15, 0.86, 0],
    [0.22, 0.76, 1],
    [0.29, 0.88, 1],
    [0.36, 0.78, 1],
    [0.43, 0.90, 1],
    [0.50, 0.80, 1],
    [0.57, 0.92, 1],
    [0.63, 0.97, 1],
    [0.84, 0.97, 0],
    [0.88, 0.88, 1],
    [0.92, 0.94, 1],
    [1.00, 0.72, 1],
  ] :
  assert(false, str("unknown profile_style: ", style)) [];

// Ornament bands per style: [u_frac_start, u_frac_end, z_frac_surface, kind]
// kind: 0 = running scroll (wide band), 1 = scallop/egg-and-dart (narrow band)
function prof_bands(style) =
  style == "ogee"         ? [[0.54, 0.80, 0.97, 0], [0.04, 0.17, 0.84, 1]] :
  style == "reverse_ogee" ? [[0.60, 0.84, 0.66, 0], [0.06, 0.20, 0.94, 1]] :
                            [[0.63, 0.84, 0.97, 0], [0.04, 0.15, 0.86, 1]];

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
