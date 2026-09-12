#!/usr/bin/env python3
"""Generate website/tokens.css from design/tokens.json.

The site is a consumer of the token set like every product is, with one
difference: it lives in the repo that holds the source, so it reads
design/tokens.json directly instead of a vendored copy. Nothing here defines a
value — a colour, size or duration the site needs and the source lacks is a
token to add there, never a literal to write here.

Konnekt's website has the same shape (frontend/scripts/gen-tokens.mjs writes
its website/tokens.css), and this generator emits the same custom-property
names so a stylesheet reads identically across the suite's sites: --bg-base,
--accent-rgb, --font-display, --text-sm, --radius-panel, --duration-fast.

Python rather than Node because this repo has no JavaScript toolchain and the
other scripts here already resolve a Python 3 interpreter (scripts/lib/python.sh).

Dark only. The site has no theme switcher and nothing sets data-theme, so a
light block would be dead CSS that reads as if light mode were supported.

Also writes assets/img/favicon.svg, whose two colours come from the same source.

Run from anywhere:  ./website/gen-tokens.py
Written only when the output actually changes, so a no-op run leaves mtimes alone.
"""

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent / "design" / "tokens.json"
OUT = HERE / "tokens.css"
FAVICON = HERE / "assets" / "img" / "favicon.svg"

SUPPORTED_VERSION = 1

# Generic families and system keywords are CSS-wide identifiers, not font names,
# and must stay unquoted. Everything else is quoted.
BARE_FAMILIES = {
    "serif", "sans-serif", "monospace", "cursive", "fantasy", "system-ui",
    "ui-serif", "ui-sans-serif", "ui-monospace", "ui-rounded", "math", "emoji",
    "fangsong", "-apple-system", "BlinkMacSystemFont",
}

BANNER = """\
/* GENERATED FILE — DO NOT EDIT.
 *
 * Produced by website/gen-tokens.py from design/tokens.json, the suite's single
 * source of design values. Hand edits are reverted by the next run and never
 * reach Konnekt or Kommands, which derive their tokens from the same source.
 *
 * To change a value: edit design/tokens.json, then run ./website/gen-tokens.py.
 * A value that is not in the source is a token to add there, not a literal to
 * inline in styles.css.
 */"""


def fail(message):
    sys.exit(f"gen-tokens: {message}")


def channels(hex_value):
    n = int(hex_value[1:], 16)
    return f"{(n >> 16) & 255} {(n >> 8) & 255} {n & 255}"


def css_color(color):
    if color.get("alpha") is None:
        return color["hex"]
    r, g, b = channels(color["hex"]).split()
    return f"rgba({r}, {g}, {b}, {color['alpha']})"


def font_stack(families, all_families):
    parts = []
    for family in families:
        if family.startswith("@"):
            target = family[1:]
            if target not in all_families:
                fail(f'font stack references "@{target}", which is not defined')
            parts.append(f"var(--font-{target})")
        elif family in BARE_FAMILIES:
            parts.append(family)
        else:
            parts.append(f"'{family}'")
    return ", ".join(parts)


def validate(src):
    # The authoritative contract is design/tokens.schema.json, checked by
    # scripts/validate-schemas.sh. Repeated here are only the checks whose
    # failure would otherwise produce plausible-looking CSS with wrong values.
    if src.get("version") != SUPPORTED_VERSION:
        fail(f"token source is version {src.get('version')}, this generator "
             f"understands {SUPPORTED_VERSION}. Update the generator, not the source.")
    for group in ("surface", "border", "text", "status"):
        if group not in src.get("color", {}):
            fail(f"missing color.{group}")
    for group in ("type", "space", "radius", "border", "motion"):
        if group not in src:
            fail(f"missing {group}")
    if len(src["motion"]["easing"].get("standard", [])) != 4:
        fail("motion.easing.standard must be four numbers")


def emit(src):
    lines = [BANNER, "", ":root {"]
    push = lines.append

    push("  /* Colours, dark theme. Status colours are emitted as a channel triplet")
    push("     and a composed value, so alpha varies from one token:")
    push("     rgb(var(--accent-rgb) / 0.3) needs no second --accent-30 token. */")
    for group, tokens in src["color"].items():
        for name, token in tokens.items():
            dark = token["dark"]
            if group == "status":
                push(f"  --{name}-rgb: {channels(dark['hex'])};")
                push(f"  --{name}: rgb(var(--{name}-rgb));")
            else:
                push(f"  --{name}: {css_color(dark)};")

    push("")
    push("  /* Type. The size scale is the app UI's — 12px body — so the site's own")
    push("     display sizes are page vocabulary in styles.css, not tokens. */")
    families = src["type"]["family"]
    for name, stack in families.items():
        push(f"  --font-{name}: {font_stack(stack, families)};")
    unit = src["type"]["size"]["unit"]
    for name, value in src["type"]["size"]["scale"].items():
        push(f"  --text-{name}: {value}{unit};")
    for name, value in src["type"]["weight"].items():
        push(f"  --weight-{name}: {value};")

    for group, prefix in (("space", "space"), ("radius", "radius"), ("border", "border")):
        push("")
        unit = src[group]["unit"]
        for name, value in src[group]["scale"].items():
            push(f"  --{prefix}-{name}: {value}{unit};")

    push("")
    unit = src["motion"]["duration"]["unit"]
    for name, value in src["motion"]["duration"]["scale"].items():
        push(f"  --duration-{name}: {value}{unit};")
    for name, points in src["motion"]["easing"].items():
        push(f"  --ease-{name}: cubic-bezier({', '.join(str(p) for p in points)});")

    push("}")
    push("")
    return "\n".join(lines)


# The favicon is the wordmark's initial on the page background. An SVG cannot
# read a custom property from a <link rel="icon">, so its two colours are
# emitted here from the same source rather than typed into an image by hand.
def emit_favicon(src):
    bg = src["color"]["surface"]["bg-base"]["dark"]["hex"]
    fg = src["color"]["status"]["accent"]["dark"]["hex"]
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">'
        f'<rect width="64" height="64" rx="14" fill="{bg}"/>'
        '<path d="M15 12h11v18.5L41 12h13L37.5 33 55 52H41.5L26 34.5V52H15z"'
        f' fill="{fg}"/>'
        "</svg>\n"
    )


def write_if_changed(path, contents):
    current = path.read_text(encoding="utf-8") if path.exists() else None
    if current == contents:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(contents, encoding="utf-8", newline="\n")
    return True


def main():
    try:
        src = json.loads(SOURCE.read_text(encoding="utf-8"))
    except FileNotFoundError:
        fail(f"no token source at {SOURCE}")
    except json.JSONDecodeError as error:
        fail(f"{SOURCE} is not valid JSON: {error}")

    validate(src)

    outputs = [(OUT, emit(src)), (FAVICON, emit_favicon(src))]
    written = [str(path.relative_to(HERE.parent)) for path, contents in outputs
               if write_if_changed(path, contents)]
    if written:
        print(f"gen-tokens: wrote {', '.join(written)}")
    else:
        names = ", ".join(str(path.relative_to(HERE.parent)) for path, _ in outputs)
        print(f"gen-tokens: {names} are already current")


if __name__ == "__main__":
    main()
