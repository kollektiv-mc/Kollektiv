# website

Kollektiv's home page: hand-written HTML and CSS with one small script, no
build step. Open `index.html` in a browser, or serve the directory:

```sh
python3 -m http.server -d website
```

## What is here

| Path | What it is |
|---|---|
| `index.html` | The one page |
| `styles.css` | Layout and the page vocabulary — every value the token set does not hold |
| `main.js` | Fills each product's pill with the release GitHub reports; the page reads fine without it |
| `tokens.css` | **Generated.** Custom properties from `design/tokens.json`. Do not edit |
| `gen-tokens.py` | Writes `tokens.css` and `assets/img/favicon.svg` from the token source |
| `assets/img/favicon.svg` | **Generated.** The wordmark's initial, coloured from the tokens |
| `assets/img/konnekt.png` | Konnekt's dashboard, the same shot its own website uses |
| `assets/img/kommands.png` | Kommands' `//generate` editor with its 3D preview, captured from a dev build |
| `assets/fonts/` | Satoshi Black, Excon Medium, Ranade Regular as woff2 — the faces `type.family` names, self-hosted |

## How it is styled

The site is a consumer of `design/tokens.json` like every product is, with one
difference: it lives in the repo that holds the source, so it reads the file
directly instead of a vendored copy. `gen-tokens.py` turns it into `tokens.css`,
and `index.html` links that ahead of `styles.css`.

```
design/tokens.json ──gen-tokens.py──▶ website/tokens.css        (committed)
                                    ▶ website/assets/img/favicon.svg
```

The custom-property names match what Konnekt's generator emits for its own
website (`--bg-base`, `--accent-rgb`, `--font-display`, `--radius-panel`,
`--duration-fast`), so a rule reads the same on either site.

**What `styles.css` may declare itself.** The token set is the *app* scale — a
12px body and 24px as its largest space — and a marketing page has display
sizes and a section rhythm no app UI has. Those live in the `:root` block at the
top of `styles.css`, marked as page vocabulary, the same split Konnekt's website
makes. Two rules keep it honest:

- Nothing in that block is a colour. Colours come from the tokens, always.
- Nothing outside that block redeclares a token or inlines a value the tokens
  hold. A value the apps could share belongs in `design/tokens.json`.

Two literals sit outside CSS and cannot read a custom property: the
`theme-color` meta tag in `index.html`, which restates `bg-base`, and the
favicon, which is why the generator writes it.

## What the pills say

Each product's pill ships saying only `desktop` or `web`. `main.js` then asks
the GitHub API, per repo, for the latest release; failing that the newest
prerelease; failing that it says `in development` with the date of the last
commit. A request that fails leaves the pill as shipped, so the page never
claims a version it did not fetch. The same element appears in the hero and in
the downloads table and is filled from one answer.

## Copy

Short, and about what a user gets. How the suite is built — the shared tokens,
the checks, the conventions — is this repo's README's to explain, not the
page's.

## Checks

`.claude/suite.json` declares `gen-tokens.py` as a generator whose output is
committed, so `./plugins/suite-kit/suite-check.py` fails when `tokens.css` or
the favicon is stale or hand-edited, and an invariant greps `styles.css` for
literal hex colours. CI runs the same clean-diff check.

## What is not here

- **A deploy.** Nothing publishes this directory yet; there is no canonical URL
  in the page for that reason.
- **A light theme.** The tokens carry light values, but the page has no theme
  switcher and nothing sets `data-theme`, so the generator emits dark only —
  same as Konnekt's site.
- **Product copy that is not true on disk.** The Kommands tile says the web
  build is not deployed and the desktop app is in development, because its
  README says so. Update the page when the products change, not before.
