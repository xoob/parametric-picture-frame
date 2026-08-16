// Parametric ornate picture frame, segmented for small-bed 3D printing.
//
// The frame is generated around a frameless canvas painting, split into
// one-piece L corners plus straight segments that each fit the selected
// printer bed, joined by glueless press-fit dovetails. The canvas sits fully
// recessed; printed clips hold it and carry the frame off the stretcher.
//
// Print orientation (all parts): decorative face UP, back plane on the bed.
// Suggested slicing: 0.6 mm nozzle, 2 walls, lightning infill, no supports.
//
// Workflow: print fit_test first, tune dovetail_clearance/shrinkage_compensation,
// then export all parts with export-all.sh.

/* [Painting] */
// Painting width (mm)
painting_width = 1300;        // [100:5:3000]
// Painting height (mm)
painting_height = 900;        // [100:5:3000]
// Painting/stretcher thickness (mm)
painting_thickness = 20;      // [5:1:60]
// Slack per side around the canvas (mm) — covers PLA shrinkage over long spans
fit_clearance = 4;            // [0:0.5:10]
// Front lip overlapping the painting face (mm)
lip_overlap = 10;             // [4:1:30]

/* [Frame look] */
// Cross-section style
profile_style = "ogee";       // [ogee, reverse_ogee, ripple]
// Moulding scale, proportional to painting size (1.0 = 5.4% of diagonal)
frame_scale = 1.0;            // [0.5:0.05:2.0]
// Generate relief ornament on the bands
ornament_enable = true;
// Ornament relief height (mm)
ornament_depth = 1.6;         // [0.6:0.2:3]
// Target ornament repeat period (mm)
ornament_period_target = 42;  // [24:2:80]
// Preview color of the frame body (previews only, not exported)
body_color = "#43280f";
// Preview color of the ornament relief (previews only, not exported)
ornament_color = "#d4a843";

/* [Printer / segmentation] */
// Bed preset
printer = "A1 Mini";          // [A1 Mini, A1, P1 X1, H2D]
// Keep-out margin per bed side (mm)
bed_margin = 2.5;             // [0:0.5:10]
// Dovetail clearance per side (mm) — press fit; tune with fit_test
dovetail_clearance = 0.08;    // [0:0.02:0.5]
// Dovetail flank taper (deg) — wedge-locks the glueless joint
dovetail_taper = 0.4;         // [0:0.1:2]
// Uniform XY scale on exported parts (1.003 = +0.3% shrink compensation)
shrinkage_compensation = 1.0; // [0.99:0.001:1.02]

/* [Output] */
render_mode = "assembled";    // [assembled, exploded, part, fit_test, clips, bom]
// Which kind of part to export (render_mode=part)
part_kind = "straight";       // [straight, corner]
// Leg; a corner is the one at this leg's CCW start: bottom=BL, right=BR, top=TR, left=TL
part_leg = "bottom";          // [bottom, right, top, left]
// Straight segment number along the leg (CCW direction)
part_index = 1;               // [1:1:12]
// Gap between parts in exploded view (mm)
explode_gap = 30;             // [0:5:100]
// Restrict assembled output to one material group (for colored GLB/3MF export)
export_group = "all";         // [all, body, ornament]

/* [Mounting] */
// Canvas recess behind the back plane (mm); also the rabbet depth minus canvas
rabbet_extra = 4;             // [2:1:10]
// Keyhole wall hangers in the two top corners (normally the frame hangs on the stretcher)
hanger_keyholes = false;

/* [Hidden] */
$fa = 5;
$fs = 0.5;          // coarsest acceptable for a 0.4 mm nozzle; we print 0.6
curve_step = 0.8;   // profile sampling step (mm)
orn_embed = 0.6;    // how deep ornament sinks into the band surface (mm)
label_depth = 0.8;  // part ID engraving depth in the back (mm)

// ---- derived dimensions (all mm) ----
sight_w = painting_width - 2 * lip_overlap;
sight_h = painting_height - 2 * lip_overlap;
lip_w = lip_overlap + fit_clearance;
face_w = 0.054 * norm([painting_width, painting_height]) * frame_scale;
rabbet_depth = painting_thickness + rabbet_extra;
profile_h = max(0.45 * face_w, rabbet_depth + 12);
frame_ow = sight_w + 2 * face_w;
frame_oh = sight_h + 2 * face_w;

bed = printer == "A1 Mini" ? [180, 180] :
      printer == "A1"      ? [256, 256] :
      printer == "P1 X1"   ? [256, 256] :
      printer == "H2D"     ? [350, 320] :
      assert(false, str("unknown printer: ", printer)) [0, 0];
usable = min(bed[0], bed[1]) - 2 * bed_margin;

include <lib/profiles.scad>
include <lib/segmentation.scad>
include <lib/ornament.scad>
include <lib/clips.scad>

PC = prof_curve(profile_style);

// dovetail geometry, centered on the solid body between rabbet wall and outer edge
dt_yc = (face_w - lip_w) / 2;
dt_wn = 0.20 * face_w;
dt_wh = 0.30 * face_w;
dt_dl = 0.16 * face_w;
dt_h = min(rabbet_depth - 2,
           profile_h * prof_min_z(PC,
             (face_w - (dt_yc + dt_wh / 2 + 2)) / face_w,
             (face_w - (dt_yc - dt_wh / 2 - 2)) / face_w) - 2.9);
dt_taper_off = tan(dovetail_taper) * dt_h;

// segmentation grids (horizontal legs: bottom/top; vertical legs: left/right).
// Every part carries its male tenon dt_dl beyond the cut — the FULL part
// including the tenon must fit the bed, so the segment budget shrinks by dt_dl.
usable_part = usable - dt_dl;
p_h = grid_period(frame_ow, ornament_period_target);
p_v = grid_period(frame_oh, ornament_period_target);
cuts_h = cuts_for(frame_ow, p_h, usable_part);
cuts_v = cuts_for(frame_oh, p_v, usable_part);
nseg_h = len(cuts_h) - 1;
nseg_v = len(cuts_v) - 1;
arm_h = cuts_h[0];
arm_v = cuts_v[0];

// ---- sanity checks ----
assert(face_w <= usable, "moulding wider than the printer bed — reduce frame_scale");
assert(profile_h * prof_min_z(PC, 0, lip_w / face_w) >= rabbet_depth + 5,
       "lip too thin over the rabbet — raise frame_scale or lower rabbet_extra");
assert(dt_h >= 8, "dovetail too shallow — raise frame_scale");
// bed-fit including the protruding tenon (a part's true bounding box)
assert(max([for (i = [1:nseg_h]) cuts_h[i] - cuts_h[i - 1]]) + dt_dl <= usable,
       "segment + tenon exceeds bed");
assert(max([for (i = [1:nseg_v]) cuts_v[i] - cuts_v[i - 1]]) + dt_dl <= usable,
       "segment + tenon exceeds bed");
assert(max(arm_h, arm_v) + dt_dl <= usable, "corner + tenon exceeds bed");
assert(scroll_w_in >= 1.3, "ornament stroke below printable width");
assert(part_index >= 1, "part_index starts at 1");

// ---- leg helpers ----
LEGS = ["b", "r", "t", "l"];
function prev_leg(leg) = leg == "b" ? "l" : leg == "r" ? "b" : leg == "t" ? "r" : "t";
function leg_letter(leg) = leg == "b" ? "B" : leg == "r" ? "R" : leg == "t" ? "T" : "L";
function corner_code(leg) = leg == "b" ? "BL" : leg == "r" ? "BR" : leg == "t" ? "TR" : "TL";
function leg_horiz(leg) = leg == "b" || leg == "t";
function legL(leg) = leg_horiz(leg) ? frame_ow : frame_oh;
function leg_p(leg) = leg_horiz(leg) ? p_h : p_v;
function leg_cuts(leg) = leg_horiz(leg) ? cuts_h : cuts_v;
function leg_nseg(leg) = leg_horiz(leg) ? nseg_h : nseg_v;
// clips sit at the centers of the odd straight segments (1, 3, 5, ...)
function clip_xs(leg) = let(cs = leg_cuts(leg))
  [for (i = [0:2:len(cs) - 2]) (cs[i] + cs[i + 1]) / 2];
n_clips = 2 * len(clip_xs("b")) + 2 * len(clip_xs("r"));

// leg-local -> global point mapping (matches leg_xform)
function leg_pt(leg, x, y) =
  leg == "b" ? [-frame_ow / 2 + x, -frame_oh / 2 + y] :
  leg == "r" ? [frame_ow / 2 - y, -frame_oh / 2 + x] :
  leg == "t" ? [frame_ow / 2 - x, frame_oh / 2 - y] :
               [-frame_ow / 2 + y, frame_oh / 2 - x];

function corner_center(leg) =
  leg == "b" ? [-frame_ow / 2 + arm_h / 2, -frame_oh / 2 + arm_v / 2] :
  leg == "r" ? [frame_ow / 2 - arm_h / 2, -frame_oh / 2 + arm_v / 2] :
  leg == "t" ? [frame_ow / 2 - arm_h / 2, frame_oh / 2 - arm_v / 2] :
               [-frame_ow / 2 + arm_h / 2, frame_oh / 2 - arm_v / 2];

function _unit2(v) = norm(v) < 1e-9 ? [1, 0] : v / norm(v);

module leg_xform(leg) {
  if (leg == "b") translate([-frame_ow / 2, -frame_oh / 2, 0]) children();
  else if (leg == "r") translate([frame_ow / 2, -frame_oh / 2, 0]) rotate([0, 0, 90]) children();
  else if (leg == "t") translate([frame_ow / 2, frame_oh / 2, 0]) rotate([0, 0, 180]) children();
  else translate([-frame_ow / 2, frame_oh / 2, 0]) rotate([0, 0, 270]) children();
}

// ---- leg geometry (leg-local: runs +X over [0,L], outer edge at y=0) ----
module leg_body(L) {
  rotate([90, 0, 90])
    linear_extrude(L, convexity = 10)
      polygon(leg_xsec_pts(PC, face_w, profile_h, lip_w, rabbet_depth, curve_step));
}

function wedge_pts(L) = [[0, 0], [L, 0], [L - face_w, face_w], [face_w, face_w]];

module leg_wedge(L) {
  linear_extrude(profile_h + ornament_depth + 2, convexity = 10)
    polygon(wedge_pts(L));
}

// full decorated leg: mitered ends, ornament, dovetail pockets, clip cavities.
// Body and ornament are separate colored solids so previews show the relief
// with contrast; exports union them into one mesh.
// x1/x2 restrict which motifs, pockets and cavities get built — pass the mask
// range when building a single part so render cost scales with the part, not
// the whole 1.45 m leg (x2 < 0 means full leg)
module leg_local(leg, x1 = 0, x2 = -1) {
  L = legL(leg);
  xe = x2 < 0 ? L : x2;
  if (export_group != "ornament")
    color(body_color) render(convexity = 10)
      difference() {
        intersection() {
          leg_body(L);
          leg_wedge(L);
        }
        for (xc = leg_cuts(leg))
          if (xc >= x1 - dt_dl - 1 && xc <= xe + dt_dl + 1) dt_pocket(xc);
        for (x = clip_xs(leg))
          if (x >= x1 - 20 && x <= xe + 20) clip_cavity(x);
      }
  if (ornament_enable && export_group != "body")
    color(ornament_color) render(convexity = 10)
      intersection() {
        ornament_leg(L, leg_p(leg), x1, xe);
        leg_wedge(L);
      }
}

// colored so intersection cut faces preview in body color, not the theme default
module mask_slab(x1, x2) {
  color(body_color)
    translate([x1, -5, -5])
      cube([x2 - x1, face_w + 10, profile_h + ornament_depth + 12]);
}

// engraved part ID, readable from the back (subtracted; positioned by caller)
module part_label(txt) {
  color(body_color)
  translate([0, 0, -0.1])
    linear_extrude(label_depth + 0.1)
      mirror([1, 0, 0]) text(txt, size = 7, halign = "center", valign = "center");
}

// keyhole hanger, carved from the back; slot toward local -y (= global up on the top leg)
module keyhole() {
  translate([0, 0, -0.1]) cylinder(d = 9, h = 4.1);
  hull() {
    translate([0, 0, -0.1]) cylinder(d = 4.5, h = 4.1);
    translate([0, -12, -0.1]) cylinder(d = 4.5, h = 4.1);
  }
  translate([0, 0, 2.2]) hull() {
    cylinder(d = 8, h = 1.9);
    translate([0, -12, 0]) cylinder(d = 8, h = 1.9);
  }
}

// ---- parts ----
// straight segment i (1-based), leg-local coordinates, back on z=0
module part_straight_inplace(leg, i) {
  cs = leg_cuts(leg);
  assert(i <= len(cs) - 1, str("part_index > ", len(cs) - 1, " for this leg"));
  x1 = cs[i - 1];
  x2 = cs[i];
  difference() {
    union() {
      intersection() {
        leg_local(leg, x1, x2);
        mask_slab(x1, x2);
      }
      color(body_color) dt_tenon(x2);
    }
    translate([(x1 + x2) / 2, dt_yc, 0]) part_label(str(leg_letter(leg), i));
  }
}

// one-piece L corner at the CCW start of `leg`, global coordinates
module part_corner_inplace(leg) {
  pl = prev_leg(leg);
  c0 = leg_cuts(leg)[0];
  cN = leg_cuts(pl)[leg_nseg(pl)];
  difference() {
    union() {
      leg_xform(pl)
        intersection() {
          leg_local(pl, cN, legL(pl));
          mask_slab(cN, legL(pl) + 1);
        }
      leg_xform(leg) {
        intersection() {
          leg_local(leg, 0, c0);
          mask_slab(-1, c0);
        }
        color(body_color) dt_tenon(c0);
      }
    }
    leg_xform(leg) translate([c0 * 0.45, dt_yc, 0]) part_label(corner_code(leg));
    if (hanger_keyholes && leg == "t")
      leg_xform("t") translate([28, 16, 0]) keyhole();
    if (hanger_keyholes && leg == "l")
      leg_xform("t") translate([legL("t") - 28, 16, 0]) keyhole();
  }
}

// ---- top-level modes ----
module frame_assembled() {
  for (leg = LEGS) {
    leg_xform(leg) leg_local(leg);
    if (export_group != "ornament")
      for (xc = leg_cuts(leg)) leg_xform(leg) color(body_color) dt_tenon(xc);
  }
}

module frame_exploded() {
  for (leg = LEGS) {
    translate(1.5 * explode_gap * _unit2(corner_center(leg)))
      part_corner_inplace(leg);
    cs = leg_cuts(leg);
    for (i = [1:len(cs) - 1])
      translate(explode_gap * _unit2(leg_pt(leg, (cs[i - 1] + cs[i]) / 2, face_w / 2)))
        leg_xform(leg) part_straight_inplace(leg, i);
  }
}

// dovetail fit-test coupon: one female block, one male block. Print both face
// up as-is, then press together face-down like the real segments.
module fit_test() {
  bw2 = dt_wh + 16;
  difference() {
    translate([0, dt_yc - bw2 / 2, 0]) cube([28, bw2, dt_h + 3]);
    dt_pocket(0);
  }
  translate([34, 0, 0]) {
    translate([0, dt_yc - bw2 / 2, 0]) cube([28, bw2, dt_h + 3]);
    dt_tenon(28);
  }
}

module painting_ghost() {
  %translate([-painting_width / 2, -painting_height / 2, rabbet_depth - painting_thickness])
    cube([painting_width, painting_height, painting_thickness]);
}

function part_leg_code() =
  part_leg == "bottom" ? "b" : part_leg == "right" ? "r" : part_leg == "top" ? "t" : "l";

if (render_mode == "assembled") {
  frame_assembled();
  painting_ghost();
} else if (render_mode == "exploded") {
  frame_exploded();
} else if (render_mode == "part") {
  scale([shrinkage_compensation, shrinkage_compensation, 1]) {
    if (part_kind == "corner") {
      cc = corner_center(part_leg_code());
      translate([-cc[0], -cc[1], 0]) part_corner_inplace(part_leg_code());
    } else {
      leg = part_leg_code();
      cs = leg_cuts(leg);
      translate([-(cs[part_index - 1] + cs[part_index]) / 2, -face_w / 2, 0])
        part_straight_inplace(leg, part_index);
    }
  }
} else if (render_mode == "fit_test") {
  color(body_color) scale([shrinkage_compensation, shrinkage_compensation, 1]) fit_test();
} else if (render_mode == "clips") {
  color(body_color) clips_plate(n_clips);
}
// render_mode == "bom": geometry-free, echo output below is the product

// ---- BOM / machine-readable info ----
echo(str("COUNTS ", nseg_h, " ", nseg_v));
echo(str("FRAME outer ", frame_ow, " x ", frame_oh, " mm, moulding ", face_w,
         " wide x ", profile_h, " high, opening for painting ",
         painting_width + 2 * fit_clearance, " x ", painting_height + 2 * fit_clearance));
echo(str("SEGMENTS bottom/top: ", nseg_h, " x ",
         [for (i = [1:nseg_h]) cuts_h[i] - cuts_h[i - 1]],
         " mm, left/right: ", nseg_v, " x ",
         [for (i = [1:nseg_v]) cuts_v[i] - cuts_v[i - 1]], " mm"));
echo(str("CORNER arms ", arm_h, " x ", arm_v, " mm (4 corners)"));
echo(str("PARTS total ", 4 + 2 * nseg_h + 2 * nseg_v, " frame pieces + ",
         n_clips, " clips; hardware: ", n_clips, " x M3x8 screws"));
echo(str("DOVETAIL neck ", dt_wn, " head ", dt_wh, " length ", dt_dl,
         " height ", dt_h, " clearance ", dovetail_clearance, " taper ", dovetail_taper, " deg"));
