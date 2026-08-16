// lib/clips.scad — canvas retainer clips + their cavities in the frame back
//
// The canvas sits fully recessed in the rabbet pocket; its back face lies
// rabbet_extra mm in front of the frame's back plane. Each clip lies in a
// clip_pocket_d deep recess in the back plane (so clip + M3 screw head end up
// sub-flush — the back stays wall-flush) and its raised nose presses the
// stretcher. Load path: frame -> clips -> stretcher -> existing wall screws.
// Print orientation: flat on its back, nose step up. No supports.

clip_w = 12;          // clip width, mm
clip_t = 3;           // clip bar thickness, mm
clip_tail = 14;       // screw-side tail length, mm
clip_body = 8;        // body between hole and pocket wall, mm
clip_nose = 8;        // nose overlap onto the stretcher, mm
clip_pocket_d = 3.5;  // recess depth in the frame back, mm
clip_pocket_w = clip_w + 2;
clip_pocket_len = clip_tail + clip_body;
clip_hole_d = 3.4;    // M3 through-hole in the clip, mm
clip_pilot_d = 2.7;   // M3 self-tap pilot in the frame, mm

// standalone clip part, printed flat (z=0 on the bed)
module clip() {
  nose_rise = rabbet_extra - clip_pocket_d;
  assert(nose_rise >= 0, "rabbet_extra must be >= clip_pocket_d");
  difference() {
    union() {
      cube([clip_pocket_len, clip_w, clip_t]);
      translate([clip_pocket_len - 0.1, 0, nose_rise])
        cube([clip_nose + 0.1, clip_w, clip_t]);
    }
    translate([clip_tail / 2, clip_w / 2, -1])
      cylinder(d = clip_hole_d, h = clip_t + rabbet_extra + 2);
  }
}

// recess + pilot hole, subtracted from a leg at leg-local x
module clip_cavity(x) color(body_color) {
  y1 = face_w - lip_w - clip_pocket_len;
  translate([x - clip_pocket_w / 2, y1, -0.1])
    cube([clip_pocket_w, clip_pocket_len + 2, clip_pocket_d + 0.1]);
  translate([x, y1 + clip_tail / 2, -1])
    cylinder(d = clip_pilot_d, h = clip_pocket_d + 11);
}

// all clips as one print plate
module clips_plate(n) {
  cols = 2;
  for (i = [0:n - 1])
    translate([(i % cols) * (clip_pocket_len + clip_nose + 8), floor(i / cols) * (clip_w + 5), 0])
      clip();
}
