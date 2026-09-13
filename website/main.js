/* Three jobs: the wireframe that turns in each tile, the hero carousel and
 * the card a tile opens into, and the release each pill names. The page reads
 * without any of them. */
;(function () {
  var STACKED = window.matchMedia('(hover: none), (max-width: 900px)')
  var REDUCED = window.matchMedia('(prefers-reduced-motion: reduce)')

  var carousel = document.getElementById('carousel')
  var hovered = false
  var carded = false

  // The carousel is held while the pointer is on it, while the card is open,
  // and while the tab is in the background — one place, so no path can leave
  // the bar running under something that should have stopped it.
  function syncHeld() {
    if (carousel) carousel.classList.toggle('is-held', hovered || carded || document.hidden)
  }

  /* ── The card a tile opens into ────────────────────────────────────────────
     A <dialog>, so the browser owns the focus trap, Escape, and inerting the
     page behind it. Its content is cloned from the tile's own <template> and
     its buttons from the tile's own actions, so a product is described in one
     place and the card cannot drift from the window it came out of. */
  var dialog = document.getElementById('detail')
  var dialogName = document.getElementById('detail-title')
  var dialogPill = document.getElementById('detail-pill')
  var dialogBody = document.getElementById('detail-body')
  var dialogActions = document.getElementById('detail-actions')
  var dialogCard = dialog && dialog.querySelector('.detail-card')
  var closing = null
  var openedFrom = null

  // The transform that lays the card over the window it came from: same
  // centre, same width. Scaled evenly rather than to the window's exact box,
  // because a card squashed to another aspect ratio distorts every word in it
  // on the way out.
  function overWindow(rect) {
    var to = dialogCard.getBoundingClientRect()
    if (!to.width || !rect) return ''
    var scale = rect.width / to.width
    var dx = rect.left + rect.width / 2 - (to.left + to.width / 2)
    var dy = rect.top + rect.height / 2 - (to.top + to.height / 2)
    return 'translate(' + dx + 'px, ' + dy + 'px) scale(' + scale + ')'
  }

  // Set a transform without animating to it, so the next change animates from
  // there rather than from wherever the card was.
  function placeCard(transform) {
    dialogCard.style.transition = 'none'
    dialogCard.style.transform = transform
    void dialogCard.offsetWidth
    dialogCard.style.transition = ''
  }

  function openCard(tile) {
    var template = tile.querySelector('.tile-detail')
    if (!dialog || !template) return
    window.clearTimeout(closing)

    // Each product's card sits on that product's own ground. A tile that names
    // none falls back to the suite's bg-overlay, which is what Konnekt uses.
    var ground = getComputedStyle(tile).getPropertyValue('--detail-bg').trim()
    if (ground) dialog.style.setProperty('--detail-bg', ground)
    else dialog.style.removeProperty('--detail-bg')

    dialogName.textContent = tile.querySelector('.tile-name').textContent
    dialogPill.innerHTML = tile.querySelector('.pill').innerHTML
    dialogBody.textContent = ''
    dialogBody.appendChild(template.content.cloneNode(true))
    dialogActions.textContent = ''
    var links = tile.querySelectorAll('.tile-more .actions a')
    for (var i = 0; i < links.length; i++) {
      var link = links[i].cloneNode(true)
      link.tabIndex = 0
      dialogActions.appendChild(link)
    }

    dialog.showModal()
    carded = true
    syncHeld()

    // Measured after showModal, when the card is where it will end up, and
    // held there for a frame — a dialog shown and styled in the same frame
    // just appears.
    var opener = tile.querySelector('.tile-window')
    openedFrom = opener ? opener.getBoundingClientRect() : null
    // placeCard flushes that starting transform, and the scrim's opacity with
    // it, so both have somewhere to animate from and neither needs to wait a
    // frame — the first frame after showModal is an expensive one, and waiting
    // for it left the card sitting on the window before it grew.
    placeCard(overWindow(openedFrom))
    dialog.classList.add('is-open')
    dialogCard.style.transform = ''
  }

  function closeCard() {
    if (!dialog || !dialog.open) return
    dialog.classList.remove('is-open')
    // Back into the window it came out of, which has not moved: the carousel
    // is held for as long as the card is open.
    dialogCard.style.transform = overWindow(openedFrom)
    carded = false
    syncHeld()
    closing = window.setTimeout(
      function () {
        dialog.close()
        placeCard('')
      },
      REDUCED.matches ? 0 : 280,
    )
  }

  if (dialog) {
    document.getElementById('detail-close').addEventListener('click', closeCard)
    // Escape: taken over so the card fades out rather than vanishing.
    dialog.addEventListener('cancel', function (event) {
      event.preventDefault()
      closeCard()
    })
    // Anywhere off the card.
    dialog.addEventListener('click', function (event) {
      if (!event.target.closest('.detail-card')) closeCard()
    })
  }

  /* ── The wireframe in each tile ────────────────────────────────────────────
     One shape per app, named by the canvas's data-shape, turning slowly on
     its own axis. Drawn rather than drawn *in*: a few dozen edges projected
     onto a canvas needs no library, and a library is a dependency this page
     has no other use for.

     The colour is read from the tile's --tile-glow-rgb at draw time — the
     same trick Kommands uses to get a token's value where it needs a colour
     rather than a class — so nothing here restates a design value. */
  // A geodesic sphere: an icosahedron with every face cut into four, and every
  // vertex pushed out onto the unit sphere. Every face is a triangle and no
  // vertex is special, which is what a sphere of latitude rings and meridians
  // cannot give — those converge on a pole, and the pinch reads as a mistake.
  function geodesic(cuts) {
    var t = (1 + Math.sqrt(5)) / 2
    var points = [
      [-1, t, 0], [1, t, 0], [-1, -t, 0], [1, -t, 0],
      [0, -1, t], [0, 1, t], [0, -1, -t], [0, 1, -t],
      [t, 0, -1], [t, 0, 1], [-t, 0, -1], [-t, 0, 1],
    ]
    var faces = [
      [0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
      [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
      [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
      [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
    ]

    function onSphere(at) {
      var p = points[at]
      var length = Math.sqrt(p[0] * p[0] + p[1] * p[1] + p[2] * p[2])
      points[at] = [p[0] / length, p[1] / length, p[2] / length]
    }
    for (var i = 0; i < points.length; i++) onSphere(i)

    for (var pass = 0; pass < cuts; pass++) {
      var middles = {}
      // One vertex per shared edge, or the two faces either side of it drift
      // apart by a rounding error and the wireframe doubles every line.
      function middle(a, b) {
        var key = Math.min(a, b) + ':' + Math.max(a, b)
        if (middles[key] === undefined) {
          points.push([
            (points[a][0] + points[b][0]) / 2,
            (points[a][1] + points[b][1]) / 2,
            (points[a][2] + points[b][2]) / 2,
          ])
          middles[key] = points.length - 1
          onSphere(middles[key])
        }
        return middles[key]
      }
      var cut = []
      faces.forEach(function (face) {
        var ab = middle(face[0], face[1])
        var bc = middle(face[1], face[2])
        var ca = middle(face[2], face[0])
        cut.push([face[0], ab, ca], [face[1], bc, ab], [face[2], ca, bc], [ab, bc, ca])
      })
      faces = cut
    }

    var seen = {}
    var edges = []
    faces.forEach(function (face) {
      for (var e = 0; e < 3; e++) {
        var a = face[e]
        var b = face[(e + 1) % 3]
        var key = Math.min(a, b) + ':' + Math.max(a, b)
        if (seen[key]) continue
        seen[key] = true
        edges.push([a, b])
      }
    })
    return {
      points: points,
      edges: edges,
      // Anywhere near the sphere, the sphere is the point's own direction.
      surface: function (p) {
        var d = Math.sqrt(p[0] * p[0] + p[1] * p[1] + p[2] * p[2]) || 1
        return [p[0] / d, p[1] / d, p[2] / d]
      },
    }
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
      return geodesic(1)
    },
    torus: function () {
      return torus(14, 7, 1, 0.42)
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
    var value = getComputedStyle(element).getPropertyValue('--tile-glow-rgb').trim()
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

  /* ── Carousel ──────────────────────────────────────────────────────────────
     An endless loop over however many products the page lists. The row is laid
     out three times over, the middle copy being the real one that assistive
     tech and the keyboard see, and the position simply walks forward along the
     whole thing. When it walks out of the middle copy it steps back by exactly
     one copy, which puts identical content in identical places, so nothing
     moves on screen.

     Three copies rather than the two clones this used to keep. With one spare
     tile at each end, the position could reach that spare and find nothing
     beyond it, so the last move of a lap slid a tile in beside an empty slot
     and the next one appeared out of nowhere once the wrap completed.

     Nothing here counts to three. Add an <article class="tile"> to the markup
     or take one away and the copies, the dots, the wrap and the nav all follow.

     What drives it is the progress bar: the product in focus animates its bar
     over --carousel-dwell and the carousel moves on when that animation ends.
     Holding pauses the bar in CSS, which is the whole of pausing. The stacked
     layout (styles.css: no hover, or under 900px) lays the tiles in a column
     and hides the bar, so there it never moves. */
  var COPIES = 3
  var heroOrbit = makeOrbit(document.getElementById('hero-orbit'))
  var track = carousel && carousel.querySelector('.carousel-track')
  if (track) {
    var products = Array.prototype.slice.call(track.children)
    var count = products.length
    var slide =
      parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--carousel-slide')) ||
      0

    // A copy is scenery: not for assistive tech, not in the tab order, and
    // without the ids the real tile's heading is labelled by.
    function asCopy(node) {
      node.setAttribute('aria-hidden', 'true')
      node.removeAttribute('aria-labelledby')
      node.removeAttribute('id')
      var ids = node.querySelectorAll('[id]')
      for (var i = 0; i < ids.length; i++) ids[i].removeAttribute('id')
      var stops = node.querySelectorAll('a, button')
      for (var j = 0; j < stops.length; j++) stops[j].tabIndex = -1
      return node
    }

    var laid = document.createDocumentFragment()
    for (var copy = 0; copy < COPIES; copy++) {
      for (var product = 0; product < count; product++) {
        // The middle copy is the markup itself, moved rather than duplicated.
        var node = copy === 1 ? products[product] : asCopy(products[product].cloneNode(true))
        node.setAttribute('data-product', String(product))
        node.setAttribute('data-copy', String(copy))
        laid.appendChild(node)
      }
    }
    track.appendChild(laid)

    // A position along the whole row, kept inside the middle copy.
    var index = count
    var settling = null

    function stride() {
      return track.children[1].offsetLeft - track.children[0].offsetLeft
    }

    function lay() {
      var centred = (carousel.clientWidth - products[0].offsetWidth) / 2
      track.style.transform = 'translateX(' + (centred - index * stride()) + 'px)'
    }

    function place(jump) {
      if (!jump) {
        lay()
        return
      }
      track.classList.add('is-jumping')
      lay()
      void track.offsetWidth // commit the jump before transitions come back
      track.classList.remove('is-jumping')
    }

    // In focus is marked on every copy of that product, so the bar it is
    // running belongs to the product and survives the step below. Which tile
    // is before and which after is a fact about position, not about product,
    // so those two are marked by where they sit.
    function mark() {
      var product = index % count
      var laidOut = track.children
      for (var i = 0; i < laidOut.length; i++) {
        var tile = laidOut[i]
        tile.classList.toggle('is-active', Number(tile.getAttribute('data-product')) === product)
        tile.classList.toggle('is-prev', i === index - 1)
        tile.classList.toggle('is-next', i === index + 1)
      }
      setShape(heroOrbit, products[product].getAttribute('data-shape'), readGlow(products[product]))
      pointDot(product)
    }

    // Back into the middle copy, one copy at a time. Identical content lands
    // in identical places, and is-jumping keeps anything from animating across
    // the step, so there is nothing to see.
    function recentre() {
      var home = (index % count) + count
      if (home === index) return
      index = home
      track.classList.add('is-jumping')
      lay()
      mark()
      void track.offsetWidth
      track.classList.remove('is-jumping')
    }

    // While the track is in flight, a tile sliding under a resting pointer
    // would light its glow on the way past. Marked here, gated in CSS.
    function moving(forMs) {
      carousel.classList.add('is-moving')
      window.clearTimeout(settling)
      settling = window.setTimeout(function () {
        carousel.classList.remove('is-moving')
        recentre()
      }, forMs)
    }

    function goTo(to) {
      if (STACKED.matches || to === index) return
      index = to
      place(false)
      mark()
      moving(slide)
    }

    // The nearest position showing that product, so a move takes the short way
    // round rather than unwinding the whole row.
    function show(product) {
      var nearest = null
      for (var pos = index - count; pos <= index + count; pos++) {
        if (pos < 0 || pos >= track.children.length || pos % count !== product) continue
        if (nearest === null || Math.abs(pos - index) < Math.abs(nearest - index)) nearest = pos
      }
      if (nearest !== null) goTo(nearest)
    }

    /* ── The indicator ───────────────────────────────────────────────────────
       One dot per product, built from the tiles so the row follows the markup.
       The travelling mark is placed by measuring the dot rather than by
       multiplying an index, which is what lets the row be any length. */
    var dots = document.getElementById('dots')
    var marks = []
    if (dots) {
      products.forEach(function (tile, product) {
        var name = tile.querySelector('.tile-name').textContent
        var dot = document.createElement('button')
        dot.type = 'button'
        dot.className = 'dot'
        dot.setAttribute('aria-label', name)
        dot.style.setProperty('--dot-glow-rgb', readGlow(tile))
        var label = document.createElement('span')
        label.className = 'dot-label'
        label.textContent = name
        dot.appendChild(label)
        dot.addEventListener('click', function () {
          show(product)
        })
        dots.appendChild(dot)
        marks.push(dot)
      })
    }

    function pointDot(product) {
      if (!marks.length) return
      for (var i = 0; i < marks.length; i++) {
        if (i === product) marks[i].setAttribute('aria-current', 'true')
        else marks[i].removeAttribute('aria-current')
      }
      var dot = marks[product]
      // The mark's own width, read rather than restated, so the token that
      // sizes it in CSS stays the only place it is decided.
      var width = parseFloat(getComputedStyle(dots, '::after').width) || 0
      dots.style.setProperty('--dot-x', dot.offsetLeft + (dot.offsetWidth - width) / 2 + 'px')
      dots.style.setProperty('--dots-glow-rgb', readGlow(products[product]))
      dots.classList.add('is-ready')
    }

    // The bar of the product in focus has filled: move on. Every copy runs one
    // in step, so only the middle copy's is counted.
    track.addEventListener('animationend', function (event) {
      if (event.animationName !== 'tile-progress') return
      var tile = event.target.closest('.tile')
      if (!tile || tile.getAttribute('data-copy') !== '1') return
      goTo(index + 1)
    })

    // The window in focus opens into the card; another comes into focus first.
    // A link inside either does what it says instead.
    track.addEventListener('click', function (event) {
      var tile = event.target.closest('.tile')
      if (!tile || event.target.closest('a')) return
      if (event.target.closest('.tile-open')) {
        openCard(tile)
        return
      }
      if (STACKED.matches) return
      event.preventDefault()
      if (tile.classList.contains('is-active')) openCard(tile)
      else goTo(Array.prototype.indexOf.call(track.children, tile))
    })

    // On the windows, not on the carousel: that is a band the width of the
    // viewport, and holding from anywhere in it stopped the carousel with the
    // pointer nowhere near a window and nothing on screen saying why.
    var windows = track.querySelectorAll('.tile-window')
    function hold() {
      hovered = true
      syncHeld()
    }
    function release() {
      hovered = false
      syncHeld()
    }
    for (var wi = 0; wi < windows.length; wi++) {
      windows[wi].addEventListener('mouseenter', hold)
      windows[wi].addEventListener('mouseleave', release)
    }

    carousel.addEventListener('focusin', function (event) {
      // Bring a tile the keyboard has reached into focus, then hold there.
      var at = products.indexOf(event.target.closest('.tile'))
      if (at !== -1) show(at)
      hold()
    })
    carousel.addEventListener('focusout', function (event) {
      if (carousel.contains(event.relatedTarget)) return
      release()
    })

    // The apps in the nav move the carousel and bring the hero back into
    // view. In the stacked layout the links stay plain anchors to the tiles.
    var gotos = document.querySelectorAll('[data-goto]')
    for (var g = 0; g < gotos.length; g++) {
      gotos[g].addEventListener('click', function (event) {
        if (STACKED.matches) return
        event.preventDefault()
        show(Number(this.getAttribute('data-goto')))
        document.getElementById('top').scrollIntoView({ behavior: 'smooth' })
      })
    }

    window.addEventListener('resize', function () {
      place(true)
      pointDot(index % count)
    })
    STACKED.addEventListener('change', function () {
      index = count
      track.style.transform = ''
      mark()
      if (!STACKED.matches) place(true)
    })

    mark()
    if (!STACKED.matches) place(true)

    startOrbits()
  }

  // A hidden tab holds the carousel and stops the wireframes: neither has
  // anything to say to someone who is not looking.
  document.addEventListener('visibilitychange', function () {
    syncHeld()
    if (document.hidden) stopOrbits()
    else startOrbits()
  })

  /* ── Release pills ─────────────────────────────────────────────────────────
     The markup ships with the platform word alone ("desktop", "web") and
     stays that way if the request fails, so nothing on the page ever claims
     a version it did not fetch. Same approach as Konnekt's own site, which
     reads its hero version from the GitHub API at load time.

     Three answers, in order:
       /releases/latest      the newest full release           → its tag
       /releases?per_page=1  newest of any kind, prereleases included → its tag
       neither               no release at all                → "in development",
                                                               and the last commit's date
     The second step matters for a project whose every release is an alpha:
     GitHub's "latest" never returns a prerelease, and a pill that fell
     straight to "in development" would understate a project that ships
     builds. A repo with no commits yet answers the commits call with 409,
     which is the same as having none. */
  var API = 'https://api.github.com/repos/'

  function get(path) {
    return fetch(API + path, { headers: { Accept: 'application/vnd.github+json' } }).then(
      function (res) {
        if (res.status === 404 || res.status === 409) return null
        if (!res.ok) throw new Error(res.status)
        return res.json()
      },
    )
  }

  function formatDate(iso) {
    var d = new Date(iso)
    if (isNaN(d)) return ''
    return d.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' })
  }

  function status(repo) {
    return get(repo + '/releases/latest').then(function (latest) {
      if (latest && latest.tag_name) return latest.tag_name
      return get(repo + '/releases?per_page=1').then(function (list) {
        if (list && list.length && list[0].tag_name) return list[0].tag_name
        return get(repo + '/commits?per_page=1').then(function (commits) {
          var when = commits && commits[0] && commits[0].commit.committer.date
          return 'in development' + (when ? ' · ' + formatDate(when) : '')
        })
      })
    })
  }

  // Queried after the carousel has made its copies, so those fill too.
  var pills = document.querySelectorAll('[data-release]')
  var byRepo = {}
  for (var i = 0; i < pills.length; i++) {
    var repo = pills[i].getAttribute('data-release')
    ;(byRepo[repo] = byRepo[repo] || []).push(pills[i])
  }

  Object.keys(byRepo).forEach(function (repo) {
    status(repo)
      .then(function (text) {
        byRepo[repo].forEach(function (pill) {
          var em = document.createElement('em')
          em.textContent = text
          pill.appendChild(em)
        })
      })
      .catch(function () {
        /* offline, rate-limited, or blocked: the pill keeps its platform word */
      })
  })
})()
