/* Two jobs: run the hero carousel, and fill every [data-release] pill with
 * what GitHub reports for that repo. The page reads fine with neither. */
;(function () {
  /* ── Carousel ──────────────────────────────────────────────────────────────
     The track holds one tile per product. For a seamless wrap it gets a copy
     of each appended, so sliding past the last real tile lands on a copy of
     the first, and once that slide has finished the track jumps back to the
     real first tile without a transition — nothing visible changes.

     It moves by itself only while nothing in it is hovered or focused, the
     tab is visible, and the viewer has not asked for reduced motion. The
     stacked layout (styles.css: no hover, or under 900px) lays the tiles in a
     column, hides the copies and pins the track, so here that is simply "do
     not move". */
  var STACKED = window.matchMedia('(hover: none), (max-width: 900px)')
  var REDUCED = window.matchMedia('(prefers-reduced-motion: reduce)')

  var carousel = document.getElementById('carousel')
  var track = carousel && carousel.querySelector('.carousel-track')
  if (track) {
    var tiles = Array.prototype.slice.call(track.children)
    var count = tiles.length
    var rootStyle = getComputedStyle(document.documentElement)
    var slide = parseFloat(rootStyle.getPropertyValue('--carousel-slide')) || 0
    var dwell = parseFloat(rootStyle.getPropertyValue('--carousel-dwell')) || 4500

    // The copies: not for assistive tech and not in the tab order, and their
    // headings drop the ids the real ones are labelled by.
    tiles.forEach(function (tile) {
      var copy = tile.cloneNode(true)
      copy.classList.add('tile-clone')
      copy.setAttribute('aria-hidden', 'true')
      copy.removeAttribute('aria-labelledby')
      var ids = copy.querySelectorAll('[id]')
      for (var i = 0; i < ids.length; i++) ids[i].removeAttribute('id')
      var links = copy.querySelectorAll('a')
      for (var j = 0; j < links.length; j++) links[j].tabIndex = -1
      track.appendChild(copy)
    })

    var index = 0
    var held = false
    var timer = null

    function stride() {
      return track.children[1].offsetLeft - track.children[0].offsetLeft
    }

    function place(jump) {
      if (jump) track.classList.add('is-jumping')
      track.style.transform = 'translateX(' + -index * stride() + 'px)'
      if (jump) {
        void track.offsetWidth // commit the jump before transitions come back
        track.classList.remove('is-jumping')
      }
    }

    function advance() {
      if (STACKED.matches) return
      index += 1
      place(false)
      if (index >= count) {
        // Sitting on a copy: after the slide, swap to the real tile in silence.
        window.setTimeout(function () {
          index -= count
          place(true)
        }, slide)
      }
    }

    function schedule() {
      window.clearTimeout(timer)
      if (held || document.hidden || REDUCED.matches || STACKED.matches) return
      timer = window.setTimeout(function () {
        advance()
        schedule()
      }, dwell)
    }

    function hold() {
      held = true
      schedule()
    }
    function release() {
      held = false
      schedule()
    }

    carousel.addEventListener('mouseenter', hold)
    carousel.addEventListener('mouseleave', release)
    carousel.addEventListener('focusin', function (event) {
      // Bring a tile the keyboard has reached into view, then hold there.
      var tile = event.target.closest('.tile')
      var at = tiles.indexOf(tile)
      if (at !== -1 && at !== index) {
        index = at
        place(false)
      }
      hold()
    })
    carousel.addEventListener('focusout', function (event) {
      if (!carousel.contains(event.relatedTarget)) release()
    })
    document.addEventListener('visibilitychange', schedule)
    window.addEventListener('resize', function () {
      place(true)
    })
    STACKED.addEventListener('change', function () {
      index = 0
      track.style.transform = ''
      schedule()
    })

    schedule()
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
