// lib/segmentation.scad — bed-aware cutting math + press-fit dovetail joints
//
// A leg runs along local +X over [0, L]; cut positions are leg-local X values.
// The ornament repeat grid and the cut grid share the same period so every seam
// lands on a motif boundary (pattern valley).

// Even number of ornament periods across the leg, symmetric about its center.
function grid_period(L, target) = L / (2 * max(1, round(L / (2 * target))));

// Cut positions for one leg: [arm_cut_low, internal cuts..., arm_cut_high].
// Corner arms (leg ends outside the outermost cuts) stay attached to the
// one-piece L corners. All cuts are multiples of the ornament period p,
// measured from the leg center. Every straight segment is <= usable.
function cuts_for(L, p, usable) =
  let(target_arm = 0.97 * usable,
      k = ceil((L / 2 - target_arm) / p))
  assert(k >= 1, str("Leg of ", L, " mm fits the bed — segmentation not needed; shrink corner arms or print whole"))
  let(cc = k * p,           // half-run length (distance of arm cuts from center)
      np = 2 * k,           // ornament periods inside the straight run
      mmax = max(1, floor(usable / p)),
      nseg = ceil(np / mmax),
      base = floor(np / nseg),
      extra = np - base * nseg,
      counts = [for (i = [0:nseg - 1])
                 (i < ceil(extra / 2) || i >= nseg - floor(extra / 2)) ? base + 1 : base])
  assert(max(counts) * p <= usable + 1e-6, "internal: segment exceeds bed")
  [for (j = [0:nseg]) L / 2 - cc + p * _psum(counts, j)];

function _psum(v, j) = j <= 0 ? 0 : _psum(v, j - 1) + v[j - 1];

// ---- Dovetail (plan-view trapezoid, vertical drop-in assembly) ----
// The male tenon belongs to the segment on the LOW-x side of a cut and points
// +x into the neighbor's pocket. Assembly: lay parts face-down, drop the tenon
// into the pocket (opening on the back face) and press — the tapered flanks
// wedge-lock. Print orientation: face up; the pocket roof is a small bridge.

function dt_poly(xc) = [
  [xc - 0.6, dt_yc - dt_wn / 2],
  [xc + dt_dl, dt_yc - dt_wh / 2],
  [xc + dt_dl, dt_yc + dt_wh / 2],
  [xc - 0.6, dt_yc + dt_wn / 2],
];

module dt_tenon(xc) {
  hull() {
    linear_extrude(0.02) polygon(dt_poly(xc));
    translate([0, 0, dt_h - 0.02])
      linear_extrude(0.02) offset(delta = -dt_taper_off) polygon(dt_poly(xc));
  }
}

module dt_pocket(xc) {
  color(body_color)  // preview only: difference faces show the subtrahend color
    translate([0, 0, -0.5])
      linear_extrude(dt_h + 0.9, convexity = 4)
        offset(delta = dovetail_clearance) polygon(dt_poly(xc));
}
