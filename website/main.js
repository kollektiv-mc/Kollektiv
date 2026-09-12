/* Fills every [data-release] pill with what GitHub reports for that repo.
 *
 * The markup ships with the platform word alone ("desktop", "web") and stays
 * that way if the request fails, so nothing on the page ever claims a version
 * it did not fetch. Same approach as Konnekt's own site, which reads its hero
 * version from the GitHub API at load time rather than hard-coding a tag.
 *
 * Three answers, in order:
 *   /releases/latest   the newest full release   → its tag
 *   /releases?per_page=1  newest of any kind, prereleases included → its tag
 *   neither            no release at all         → "in development", and the
 *                                                   date of the last commit
 * The second step matters for a project whose every release is an alpha:
 * GitHub's "latest" never returns a prerelease, and a pill that fell straight
 * to "in development" would understate a project that ships builds. */
;(function () {
  var API = 'https://api.github.com/repos/'

  function get(path) {
    return fetch(API + path, { headers: { Accept: 'application/vnd.github+json' } }).then(
      function (res) {
        if (res.status === 404) return null
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
    return get(repo + '/releases/latest')
      .then(function (latest) {
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
