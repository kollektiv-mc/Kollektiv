---
description: Verify Minecraft Java Edition command syntax, item and entity IDs, components, attributes, enchantments, effects, particles, and selectors against the pinned data for the target version before writing or changing them. Use whenever a task involves emitting, parsing, serializing, or validating a Minecraft command or a game identifier.
---

# Minecraft syntax

**Assume your recollection of Minecraft syntax is wrong until checked.** This is
not ordinary caution. Command syntax changes between point releases in ways that
produce output which parses, looks plausible, and silently does nothing — and
training data on it is unusually stale and unusually confident.

Read `.claude/suite.json` → `minecraft` for this repo's `targetVersion`,
`dataSource`, and `traitMatrix`. Read the trait matrix before touching a serializer.

---

## Check before you write, not after

The order matters. Verifying afterwards means writing plausible-looking syntax
first, and plausible-looking syntax is exactly what survives review.

Sources, in order of authority:

1. **The repo's own pinned registry data** — derived from the pinned data-source
   tag. If the value should be in there and is not, that is the finding.
2. **[minecraft.wiki](https://minecraft.wiki)** for the specific version. Check
   which version a page's syntax describes; pages routinely document latest.
3. Anything else is a hypothesis, not a source.

## Version differences are traits, never comparisons

A serializer branches on a named trait from the matrix. It never compares a version
string. `version === '1.21.1'` anywhere in application code is a bug, not a
shortcut — it is the exact construct that silently emits wrong output the moment a
version is added.

If a difference has no trait yet, add the trait. Do not inline the comparison and
plan to generalise later.

## Identifiers are versioned data

Item IDs, entity IDs, enchantments, effects, particles, attributes, selectors, and
colour codes are **data**, read from the version registry. They are not string
literals in application code, even once, even temporarily.

## Say what you checked

When reporting, name the source and the version you verified against. "Verified
against the pinned 1.21.1 registry" and "I believe this is right" are different
claims, and only one of them is worth anything to the person reading it.

If you could not verify something — the registry does not cover it, the wiki is
ambiguous about which version it documents — say so plainly and leave it flagged.
An unverified value called out is a small problem; an unverified value presented as
checked is the failure this skill exists to prevent.
