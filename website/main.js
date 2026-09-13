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
  var closing = null

  function openCard(tile) {
    var template = tile.querySelector('.tile-detail')
    if (!dialog || !template) return
    window.clearTimeout(closing)

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
    // Painted closed, then opened, so the scale and fade have a frame to
    // start from — a dialog shown and styled in the same frame just appears.
    window.requestAnimationFrame(function () {
      dialog.classList.add('is-open')
    })
  }

  function closeCard() {
    if (!dialog || !dialog.open) return
    dialog.classList.remove('is-open')
    carded = false
    syncHeld()
    closing = window.setTimeout(function () {
      dialog.close()
    }, REDUCED.matches ? 0 : 280)
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
  function sphere(bands, meridians) {
    // bands horizontally (poles included), meridians vertically.
    var points = [[0, 1, 0], [0, -1, 0]]
    var edges = []
    var rings = []
    for (var i = 1; i < bands; i++) {
      var phi = (Math.PI * i) / bands
      var ring = []
      for (var j = 0; j < meridians; j++) {
        var theta = (2 * Math.PI * j) / meridians
        points.push([
          Math.sin(phi) * Math.cos(theta),
          Math.cos(phi),
          Math.sin(phi) * Math.sin(theta),
        ])
        ring.push(points.length - 1)
      }
      rings.push(ring)
    }
    rings.forEach(function (ring) {
      ring.forEach(function (at, k) {
        edges.push([at, ring[(k + 1) % ring.length]])
      })
    })
    for (var m = 0; m < meridians; m++) {
      var chain = [0]
      rings.forEach(function (ring) {
        chain.push(ring[m])
      })
      chain.push(1)
      for (var c = 0; c + 1 < chain.length; c++) edges.push([chain[c], chain[c + 1]])
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
    return { points: points, edges: edges }
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
      return sphere(4, 8)
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
  var TILT = 0.5
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

  function makeOrbit(canvas) {
    var shape = SHAPES[canvas.getAttribute('data-shape')]
    if (!shape || !canvas.getContext) return
    var geometry = shape()
    // Normalised by its own reach, so a cube (corners at √3) and a sphere
    // (surface at 1) end up drawn the same size rather than the cube spilling
    // out of the canvas.
    var reach = 0
    geometry.points.forEach(function (point) {
      reach = Math.max(reach, Math.sqrt(point[0] * point[0] + point[1] * point[1] + point[2] * point[2]))
    })
    var orbit = {
      canvas: canvas,
      ctx: canvas.getContext('2d'),
      geometry: geometry,
      reach: reach || 1,
      glow: readGlow(canvas.closest('.tile') || canvas),
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
  }

  function paint(orbit, time) {
    var ctx = orbit.ctx
    var w = orbit.w
    var h = orbit.h
    if (!w || !h) return
    ctx.clearRect(0, 0, w, h)

    var angle = time * SPIN
    var cos = Math.cos(angle)
    var sin = Math.sin(angle)
    var tiltCos = Math.cos(TILT)
    var tiltSin = Math.sin(TILT)
    var scale = (Math.min(w, h) * 0.42) / orbit.reach
    var screen = orbit.geometry.points.map(function (point) {
      // Spin about the vertical axis, then tip the whole thing towards us.
      var x = point[0] * cos + point[2] * sin
      var z = point[2] * cos - point[0] * sin
      var y = point[1] * tiltCos - z * tiltSin
      var depth = z * tiltCos + point[1] * tiltSin
      var perspective = 4 / (4 - depth)
      return [w / 2 + x * scale * perspective, h / 2 - y * scale * perspective, depth]
    })

    ctx.lineWidth = 1
    orbit.geometry.edges.forEach(function (edge) {
      var a = screen[edge[0]]
      var b = screen[edge[1]]
      // Nearer edges draw stronger, which is the whole of the depth cue.
      var near = (a[2] + b[2]) / 2
      ctx.strokeStyle = 'rgba(' + orbit.glow + ', ' + (0.18 + 0.5 * ((near + 1) / 2)) + ')'
      ctx.beginPath()
      ctx.moveTo(a[0], a[1])
      ctx.lineTo(b[0], b[1])
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
     The track holds one tile per product, with a copy of the last placed
     before the first and a copy of the first after the last, so the window in
     focus always has a neighbour on each side and sliding past either end
     lands on a copy; once that slide has finished the track jumps to the real
     tile without a transition, and nothing visible changes.

     What drives it is the progress bar: the tile in focus animates its bar
     over --carousel-dwell and the carousel moves on when that animation ends.
     Holding pauses the bar in CSS, which is the whole of pausing. The stacked
     layout (styles.css: no hover, or under 900px) lays the tiles in a column
     and hides the bar, so there it never moves. */
  var track = carousel && carousel.querySelector('.carousel-track')
  if (track) {
    var tiles = Array.prototype.slice.call(track.children)
    var count = tiles.length
    var slide =
      parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--carousel-slide')) ||
      0

    // A copy: not for assistive tech, not in the tab order, and without the
    // ids the real tile's heading is labelled by. It remembers which real
    // tile it stands for, so it can be in focus alongside it.
    function copyOf(at) {
      var copy = tiles[at].cloneNode(true)
      copy.classList.add('tile-clone')
      copy.setAttribute('aria-hidden', 'true')
      copy.removeAttribute('aria-labelledby')
      copy.removeAttribute('id')
      copy.setAttribute('data-clone-of', String(at))
      var ids = copy.querySelectorAll('[id]')
      for (var i = 0; i < ids.length; i++) ids[i].removeAttribute('id')
      var stops = copy.querySelectorAll('a, button')
      for (var j = 0; j < stops.length; j++) stops[j].tabIndex = -1
      return copy
    }
    track.insertBefore(copyOf(count - 1), track.firstChild)
    track.appendChild(copyOf(0))

    // index counts real positions; -1 and count are the copies, briefly.
    var index = 0

    function real(i) {
      return ((i % count) + count) % count
    }

    function stride() {
      return track.children[1].offsetLeft - track.children[0].offsetLeft
    }

    function place(jump) {
      if (jump) track.classList.add('is-jumping')
      var centred = (carousel.clientWidth - tiles[0].offsetWidth) / 2
      track.style.transform = 'translateX(' + (centred - (index + 1) * stride()) + 'px)'
      if (jump) {
        void track.offsetWidth // commit the jump before transitions come back
        track.classList.remove('is-jumping')
      }
    }

    // The real tile in focus and its copy, if any, are in focus together, so
    // their bars start at the same moment and agree after a jump. The tiles
    // either side of the one on screen are marked too, by track position, so
    // each can lay its name on the edge that shows.
    function mark() {
      var active = real(index)
      var all = track.children
      for (var i = 0; i < all.length; i++) {
        var tile = all[i]
        var stands = tile.hasAttribute('data-clone-of')
          ? Number(tile.getAttribute('data-clone-of'))
          : tiles.indexOf(tile)
        tile.classList.toggle('is-active', stands === active)
        tile.classList.toggle('is-prev', i === index)
        tile.classList.toggle('is-next', i === index + 2)
      }
    }

    function goTo(i) {
      if (STACKED.matches || i === index) return
      index = i
      place(false)
      mark()
      if (index < 0 || index >= count) {
        // Sitting on a copy: after the slide, swap to the real tile in silence.
        window.setTimeout(function () {
          index = real(index)
          place(true)
          mark()
        }, slide)
      }
    }

    // The bar of the tile in focus has filled: move on. Copies animate too,
    // in step with their real tile, and are ignored so this fires once.
    track.addEventListener('animationend', function (event) {
      if (event.animationName !== 'tile-progress') return
      var tile = event.target.closest('.tile')
      if (!tile || tile.classList.contains('tile-clone')) return
      goTo(real(index) + 1)
    })

    // The window in focus opens into the card; a neighbour comes into focus
    // first. A link inside either does what it says instead.
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
      else goTo(Array.prototype.indexOf.call(track.children, tile) - 1)
    })

    carousel.addEventListener('mouseenter', function () {
      hovered = true
      syncHeld()
    })
    carousel.addEventListener('mouseleave', function () {
      hovered = false
      syncHeld()
    })
    carousel.addEventListener('focusin', function (event) {
      // Bring a tile the keyboard has reached into focus, then hold there.
      var at = tiles.indexOf(event.target.closest('.tile'))
      if (at !== -1) goTo(at)
      hovered = true
      syncHeld()
    })
    carousel.addEventListener('focusout', function (event) {
      if (carousel.contains(event.relatedTarget)) return
      hovered = false
      syncHeld()
    })

    // The apps in the nav move the carousel and bring the hero back into
    // view. In the stacked layout the links stay plain anchors to the tiles.
    var gotos = document.querySelectorAll('[data-goto]')
    for (var g = 0; g < gotos.length; g++) {
      gotos[g].addEventListener('click', function (event) {
        if (STACKED.matches) return
        event.preventDefault()
        goTo(Number(this.getAttribute('data-goto')))
        document.getElementById('top').scrollIntoView({ behavior: 'smooth' })
      })
    }

    window.addEventListener('resize', function () {
      place(true)
    })
    STACKED.addEventListener('change', function () {
      index = 0
      track.style.transform = ''
      mark()
      if (!STACKED.matches) place(true)
    })

    mark()
    if (!STACKED.matches) place(true)

    // After the copies exist, so they turn too.
    var canvases = track.querySelectorAll('.tile-orbit')
    for (var c = 0; c < canvases.length; c++) makeOrbit(canvases[c])
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
