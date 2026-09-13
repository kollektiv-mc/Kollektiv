/* Two jobs: run the hero carousel, and fill every [data-release] pill with
 * what GitHub reports for that repo. The page reads fine with neither. */
;(function () {
  /* ── Carousel ──────────────────────────────────────────────────────────────
     The track holds one tile per product, with a copy of the last placed
     before the first and a copy of the first after the last, so the window
     in focus always has a neighbour on each side and sliding past either end
     lands on a copy; once that slide has finished the track jumps to the real
     tile without a transition, and nothing visible changes.

     What drives it is the progress bar: the tile in focus animates its bar
     over --carousel-dwell and the carousel moves on when that animation ends.
     Holding (hover or focus) pauses the bar in CSS, which is the whole of
     pausing. The stacked layout (styles.css: no hover, or under 900px) lays
     the tiles in a column and hides the bar, so there it never moves. */
  var STACKED = window.matchMedia('(hover: none), (max-width: 900px)')

  var carousel = document.getElementById('carousel')
  var track = carousel && carousel.querySelector('.carousel-track')
  if (track) {
    var tiles = Array.prototype.slice.call(track.children)
    var count = tiles.length
    var slide =
      parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--carousel-slide')) || 0

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
      var links = copy.querySelectorAll('a')
      for (var j = 0; j < links.length; j++) links[j].tabIndex = -1
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
    // either side of the one on screen are marked too, by track position,
    // so each can lay its name on the edge that shows.
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

    // A neighbour, clicked, comes into focus; a link inside it does not fire.
    track.addEventListener('click', function (event) {
      var tile = event.target.closest('.tile')
      if (!tile || STACKED.matches) return
      var at = Array.prototype.indexOf.call(track.children, tile) - 1
      if (at === index) return
      event.preventDefault()
      goTo(at)
    })

    function hold() {
      carousel.classList.add('is-held')
    }
    function release() {
      carousel.classList.remove('is-held')
    }
    carousel.addEventListener('mouseenter', hold)
    carousel.addEventListener('mouseleave', release)
    carousel.addEventListener('focusin', function (event) {
      // Bring a tile the keyboard has reached into focus, then hold there.
      var at = tiles.indexOf(event.target.closest('.tile'))
      if (at !== -1) goTo(at)
      hold()
    })
    carousel.addEventListener('focusout', function (event) {
      if (!carousel.contains(event.relatedTarget)) release()
    })
    document.addEventListener('visibilitychange', function () {
      // A hidden tab holds too, so the bar does not fill unwatched.
      if (document.hidden) hold()
      else if (!carousel.matches(':hover')) release()
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
  }

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
