/* The wireframe that turns behind the carousel. Its own file because main.js
 * was past the size this repo's aislop ratchet allows, and this is the part
 * with the cleanest seam: pure geometry and canvas painting, reached through
 * the five functions published at the bottom. Loaded before main.js, which is
 * what puts window.KollektivShapes there in time.
 *
 * readGlow lives here too, with the drawing code that needs a token as a
 * value. .claude/skills aside, that is why .claude/suite.json's no-literal
 * -colours invariant names this file as well as styles.css and main.js. */
;(function () {
  var REDUCED = window.matchMedia('(prefers-reduced-motion: reduce)')

  /* ── The wireframe in each tile ────────────────────────────────────────────
     One shape per app, named by the canvas's data-shape, turning slowly on
     its own axis. Drawn rather than drawn *in*: a few dozen edges projected
     onto a canvas needs no library, and a library is a dependency this page
     has no other use for.

     The colour is read from the tile's --product-rgb at draw time — the
     same trick Kommands uses to get a token's value where it needs a colour
     rather than a class — so nothing here restates a design value. */
  // A wireframe globe: parallels and meridians, the way a globe is drawn.
  // `bands` is how many slices pole to pole, so it leaves bands - 1 parallels
  // and puts one on the equator whenever it is even. `meridians` are the
  // half circles joining the poles.
  //
  // Both are emitted already curved, at `steps` segments each, rather than as
  // a few long edges bent later by surface(). That walk pushes every midpoint
  // out to radius 1, which is right for a meridian, since a meridian is a
  // great circle, and wrong for a parallel: a parallel is a small circle, and
  // its midpoints would be pushed off it towards the pole. Drawing the curve
  // directly is both correct and simpler, and it is why this shape publishes
  // no surface().
  function globe(bands, meridians, steps) {
    var points = []
    var edges = []

    function at(lat, lon) {
      points.push([Math.cos(lat) * Math.sin(lon), Math.sin(lat), Math.cos(lat) * Math.cos(lon)])
      return points.length - 1
    }

    for (var band = 1; band < bands; band++) {
      var lat = Math.PI * (band / bands - 0.5)
      var first = points.length
      for (var s = 0; s < steps; s++) {
        var here = at(lat, (2 * Math.PI * s) / steps)
        // The ring closes: the last segment runs back to where it started.
        if (s > 0) edges.push([here - 1, here])
      }
      edges.push([points.length - 1, first])
    }

    for (var m = 0; m < meridians; m++) {
      var lon = (2 * Math.PI * m) / meridians
      for (var t = 0; t <= steps; t++) {
        var down = at(Math.PI * (t / steps - 0.5), lon)
        if (t > 0) edges.push([down - 1, down])
      }
    }

    return { points: points, edges: edges }
  }

  function torus(major, minor, R, r) {
    var points = []
    var edges = []
    for (var i = 0; i < major; i++) {
      var u = (2 * Math.PI * i) / major
      for (var j = 0; j < minor; j++) {
        var v = (2 * Math.PI * j) / minor
        points.push([
          (R + r * Math.cos(v)) * Math.cos(u),
          r * Math.sin(v),
          (R + r * Math.cos(v)) * Math.sin(u),
        ])
      }
    }
    var at = function (i, j) {
      return ((i + major) % major) * minor + ((j + minor) % minor)
    }
    for (var a = 0; a < major; a++) {
      for (var b = 0; b < minor; b++) {
        edges.push([at(a, b), at(a + 1, b)])
        edges.push([at(a, b), at(a, b + 1)])
      }
    }
    return {
      points: points,
      edges: edges,
      // Out to the ring, then out from the ring: the nearest point on the tube.
      surface: function (p) {
        var flat = Math.sqrt(p[0] * p[0] + p[2] * p[2]) || 1
        var cx = (p[0] / flat) * R
        var cz = (p[2] / flat) * R
        var dx = p[0] - cx
        var dz = p[2] - cz
        var d = Math.sqrt(dx * dx + p[1] * p[1] + dz * dz) || 1
        return [cx + (dx / d) * r, (p[1] / d) * r, cz + (dz / d) * r]
      },
    }
  }

  function cube() {
    var points = []
    for (var i = 0; i < 8; i++) {
      points.push([i & 1 ? 1 : -1, i & 2 ? 1 : -1, i & 4 ? 1 : -1])
    }
    var edges = []
    for (var a = 0; a < 8; a++) {
      for (var b = a + 1; b < 8; b++) {
        // Neighbours differ in exactly one axis: that is an edge, not a diagonal.
        var differs = 0
        for (var axis = 0; axis < 3; axis++) if (points[a][axis] !== points[b][axis]) differs++
        if (differs === 1) edges.push([a, b])
      }
    }
    return { points: points, edges: edges }
  }

  var SHAPES = {
    sphere: function () {
      return globe(6, 8, 48)
    },
    torus: function () {
      return torus(10, 5, 1, 0.42)
    },
    cube: function () {
      return cube()
    },
  }

  // Radians per millisecond. A turn takes about a minute: present, but never
  // the thing being looked at.
  var SPIN = 0.0001
  // How far each shape is tipped towards the viewer. Per shape rather than
  // one for all: a torus at the angle that suits a sphere is seen nearly
  // edge-on, and reads as an arc rather than as a ring.
  var TILT = { sphere: 0.62, torus: 1, cube: 0.62 }
  // How long the old shape takes to go and the new one to arrive, together.
  var MORPH = 600
  // Steps an edge of a curved surface is walked in. Eight is where a great
  // circle stops looking like a chain of straight lines at this size.
  var CURVE = 8
  var orbits = []
  var lastTime = 0

  function readGlow(element) {
    var value = getComputedStyle(element).getPropertyValue('--product-rgb').trim()
    // A tile that inherits the suite accent reports the reference on some
    // engines rather than the value; resolve it the one way that always works.
    if (!value || value.indexOf('var(') === 0) {
      value = getComputedStyle(document.documentElement).getPropertyValue('--accent-rgb').trim()
    }
    return value.split(/[\s,]+/).slice(0, 3).join(', ')
  }

  // Built once each. shapeOf used to return a new object every call, which
  // made the "already showing this" test below compare two fresh objects and
  // never match — so every mark(), and a wrap runs two in a row, restarted the
  // morph and the shape flashed.
  var built = {}

  function shapeOf(name) {
    var shape = SHAPES[name]
    if (!shape) return null
    if (built[name]) return built[name]
    var geometry = shape()
    // Normalised by its own reach, so a cube (corners at √3) and a sphere
    // (surface at 1) end up drawn the same size rather than the cube spilling
    // out of the canvas.
    var reach = 0
    geometry.points.forEach(function (point) {
      reach = Math.max(reach, Math.sqrt(point[0] * point[0] + point[1] * point[1] + point[2] * point[2]))
    })
    built[name] = { name: name, geometry: geometry, reach: reach || 1, tilt: TILT[name] || 0.62 }
    return built[name]
  }

  function makeOrbit(canvas) {
    if (!canvas || !canvas.getContext) return null
    var orbit = {
      canvas: canvas,
      ctx: canvas.getContext('2d'),
      shape: null,
      glow: readGlow(document.documentElement),
      pending: null,
      morphFrom: 0,
      w: 0,
      h: 0,
    }

    function size() {
      var dpr = Math.min(window.devicePixelRatio || 1, 2)
      var rect = canvas.getBoundingClientRect()
      if (!rect.width || !rect.height) return
      orbit.w = rect.width
      orbit.h = rect.height
      canvas.width = Math.round(rect.width * dpr)
      canvas.height = Math.round(rect.height * dpr)
      orbit.ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
      // Resizing clears the canvas, and when nothing is animating there is no
      // next frame to fill it again. This is the whole of what is drawn for a
      // viewer who asked for reduced motion: the first size that arrives is
      // after the one paint, so that paint has to happen here.
      if (!running) paint(orbit, lastTime)
    }
    size()
    if (window.ResizeObserver) new ResizeObserver(size).observe(canvas)
    orbits.push(orbit)
    return orbit
  }

  // Swap in another app's shape and colour. The old one fades out, the new one
  // fades in, and the change happens at the point where neither is on screen.
  function setShape(orbit, name, glow) {
    if (!orbit) return
    var shape = shapeOf(name)
    if (!shape) return
    if (!orbit.shape || REDUCED.matches) {
      orbit.shape = shape
      orbit.glow = glow
      orbit.pending = null
      orbit.morphFrom = 0
      if (!running) paint(orbit, lastTime)
      return
    }
    // Compared by name and colour against whatever is on its way in, so a
    // second call naming what is already showing changes nothing.
    var showing = orbit.pending || orbit
    if (showing.shape.name === name && showing.glow === glow) return
    orbit.pending = { shape: shape, glow: glow }
    orbit.morphFrom = lastTime
  }

  function paint(orbit, time) {
    var ctx = orbit.ctx
    var w = orbit.w
    var h = orbit.h
    if (!w || !h || !orbit.shape) return
    ctx.clearRect(0, 0, w, h)

    // Out over the first half of the morph, in over the second, with the swap
    // itself at the bottom of the dip.
    var fade = 1
    if (orbit.morphFrom) {
      var through = (time - orbit.morphFrom) / MORPH
      if (through >= 1) {
        orbit.morphFrom = 0
      } else if (through < 0.5) {
        fade = 1 - through * 2
      } else {
        if (orbit.pending) {
          orbit.shape = orbit.pending.shape
          orbit.glow = orbit.pending.glow
          orbit.pending = null
        }
        fade = (through - 0.5) * 2
      }
    }

    var angle = time * SPIN
    var cos = Math.cos(angle)
    var sin = Math.sin(angle)
    var tiltCos = Math.cos(orbit.shape.tilt)
    var tiltSin = Math.sin(orbit.shape.tilt)
    var scale = (Math.min(w, h) * 0.42) / orbit.shape.reach

    function project(point) {
      // Spin about the vertical axis, then tip the whole thing towards us.
      var x = point[0] * cos + point[2] * sin
      var z = point[2] * cos - point[0] * sin
      var y = point[1] * tiltCos - z * tiltSin
      var depth = z * tiltCos + point[1] * tiltSin
      var perspective = 4 / (4 - depth)
      return [w / 2 + x * scale * perspective, h / 2 - y * scale * perspective, depth]
    }

    var geometry = orbit.shape.geometry
    var points = geometry.points
    // An edge of a curved surface is a curve. Drawn as one straight line it
    // cuts the corner, and a ball of cut corners is a polyhedron rather than a
    // sphere. So a curved shape's edges are walked in steps, with every step
    // put back onto the surface before it is projected; a cube has no curve to
    // follow and keeps its two ends.
    var steps = geometry.surface ? CURVE : 1

    // Wider than a hairline on purpose; the canvas is blurred in CSS and a
    // one-pixel line does not survive that. See .hero-orbit.
    ctx.lineWidth = 1.6
    ctx.lineCap = 'round'
    ctx.lineJoin = 'round'
    geometry.edges.forEach(function (edge) {
      var a = points[edge[0]]
      var b = points[edge[1]]
      ctx.beginPath()
      var depth = 0
      for (var step = 0; step <= steps; step++) {
        var along = step / steps
        var point = [
          a[0] + (b[0] - a[0]) * along,
          a[1] + (b[1] - a[1]) * along,
          a[2] + (b[2] - a[2]) * along,
        ]
        if (geometry.surface) point = geometry.surface(point)
        var at = project(point)
        if (step === 0) ctx.moveTo(at[0], at[1])
        else ctx.lineTo(at[0], at[1])
        if (step === 0 || step === steps) depth += at[2] / 2
      }
      // Nearer edges draw stronger, which is the whole of the depth cue.
      ctx.strokeStyle =
        'rgba(' + orbit.glow + ', ' + fade * (0.18 + 0.5 * ((depth + 1) / 2)) + ')'
      ctx.stroke()
    })
  }

  var running = false
  function frame(time) {
    lastTime = time
    for (var i = 0; i < orbits.length; i++) paint(orbits[i], time)
    if (running) window.requestAnimationFrame(frame)
  }

  function startOrbits() {
    if (!orbits.length) return
    if (REDUCED.matches) {
      // Still there, just not turning.
      for (var i = 0; i < orbits.length; i++) paint(orbits[i], 0)
      return
    }
    if (running) return
    running = true
    window.requestAnimationFrame(frame)
  }

  function stopOrbits() {
    running = false
  }

  // The page's one handle on all of this. A namespace rather than five globals,
  // and assigned last so a half-built object is never visible.
  window.KollektivShapes = {
    makeOrbit: makeOrbit,
    setShape: setShape,
    readGlow: readGlow,
    startOrbits: startOrbits,
    stopOrbits: stopOrbits,
  }
})()
