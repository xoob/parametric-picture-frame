// lib/ornament.scad — mathematically generated relief ornament
//
// Two band motifs, both emitted as single valid polygons (no self-intersection):
//  * running scroll: squashed Archimedean-style spiral r = R*(th/thmax)^k,
//    stroked with a tapering width, alternately rotated 180 deg (Vitruvian wave)
//  * scallop: half-annulus arc + central dart (egg-and-dart flavor)
// Relief height is ornament_depth; minimum stroke width stays >= 1.35 mm so a
// 0.6 mm nozzle (and 0.4 mm for compatibility) can print every ridge.

function _unit(v) = v / max(norm(v), 1e-9);

// stroke a polyline into a closed polygon, width lerping w0 -> w1 along it
function stroke_poly(pts, w0, w1) =
  let(n = len(pts) - 1,
      ts = [for (i = [0:n]) _unit(pts[min(i + 1, n)] - pts[max(i - 1, 0)])],
      ws = [for (i = [0:n]) w0 + (w1 - w0) * i / n],
      lft = [for (i = [0:n]) pts[i] + [-ts[i][1], ts[i][0]] * ws[i] / 2],
      rgt = [for (i = [0:n]) pts[i] - [-ts[i][1], ts[i][0]] * ws[i] / 2])
  concat(lft, [for (i = [n:-1:0]) rgt[i]]);

// spiral polyline from the outer end (theta=thmax) inward to theta=th0
function spiral_pts(R, sy, th0, thmax, kexp, step) =
  [for (th = [thmax:-step:th0])
    let(r = R * pow(th / thmax, kexp)) [r * cos(th), r * sin(th) * sy]];

scroll_w_out = 2.3;  // outer stroke width, mm
scroll_w_in = 1.35;  // stroke width at the spiral tip, mm

// 2D running-scroll motif centered on the origin, one ornament period wide
module scroll_motif(p, bw) {
  R = 0.40 * p;
  sy = min(0.62, (bw / 2 - scroll_w_out / 2 - 0.6) / R);
  pts = spiral_pts(R, sy, 90, 1080, 0.85, 12);
  tip = pts[len(pts) - 1];
  intersection() {
    union() {
      polygon(stroke_poly(pts, scroll_w_out, scroll_w_in));
      translate(tip) circle(d = scroll_w_in * 1.4);
      circle(d = 2.2);  // spiral eye
    }
    square([p - 1.0, bw - 0.4], center = true);
  }
}

// 2D scallop motif: half-annulus + dart, base sitting on the band's inner side
module scallop_motif(p2, bw) {
  R = min(0.44 * p2, 0.85 * bw);
  t = 1.6;
  intersection() {
    translate([0, -bw / 2 + 0.3]) union() {
      polygon(concat(
        [for (a = [0:7.5:180]) R * [cos(a), sin(a)]],
        [for (a = [180:-7.5:0]) (R - t) * [cos(a), sin(a)]]));
      polygon([[-1.0, 0], [1.0, 0], [0, max(R - t - 0.8, 2)]]);
    }
    square([p2 - 0.8, bw - 0.4], center = true);
  }
}

// extruded, cache-friendly motif (identical instances hit the geometry cache)
module motif3d(kind, p, bw) {
  render(convexity = 6)
    linear_extrude(orn_embed + ornament_depth, convexity = 6) {
      if (kind == 0) scroll_motif(p, bw);
      else scallop_motif(p, bw);
    }
}

// all ornament bands along one leg (leg-local coordinates), restricted to
// cells overlapping [x1, x2] — parts only build their own motifs, which keeps
// non-Manifold backends (MakerWorld) within usable render times
module ornament_leg(L, p, x1, x2) {
  n = round(L / p);
  for (b = prof_bands(profile_style)) {
    ybc = face_w - (b[0] + b[1]) / 2 * face_w;
    bw = (b[1] - b[0]) * face_w;
    zb = b[2] * profile_h - orn_embed;
    if (b[3] == 0) {
      for (i = [0:n - 1])
        if ((i + 1) * p >= x1 && i * p <= x2)
          translate([(i + 0.5) * p, ybc, zb])
            rotate([0, 0, i % 2 == 0 ? 0 : 180]) motif3d(0, p, bw);
    } else {
      for (i = [0:2 * n - 1])
        if ((i + 1) * p / 2 >= x1 && i * p / 2 <= x2)
          translate([(i + 0.5) * p / 2, ybc, zb]) motif3d(1, p / 2, bw);
    }
  }
}
