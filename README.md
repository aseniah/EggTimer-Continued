# EggTimer Continued

Tracks unique, vendor-bought perishable items that auto-transform after a few
real-time days, across every character on your account:

| You buy | It becomes | After |
|---|---|---|
| Mysterious Egg | Cracked Egg | ~3 days |
| Disgusting Jar | Ripe Disgusting Jar | ~3 days |

These come from the Oracles / Frenzyheart quartermasters in Sholazar Basin and
are the source of several rare pets and mounts. They're bought, not looted, so
nothing in the default UI reminds you they exist, and they ripen while the
character is offline. If you farm them on alts across realms, it's easy to
forget a jar has been sitting ready for a week.

## What it does

- Scans your bags on login and whenever bag contents change. Readiness is driven
  by the transformed item actually appearing in your bags, not by a guessed
  clock, so it's never wrong about "ready".
- Stores state account-wide, keyed by `Name-Realm`, so an alt on another realm
  shows up on your main.
- On every login, and within ~30s if it happens while you're playing, tells you
  (chat line + optional chime) when something is ready to collect and **which
  character to switch to**. Repeats every session until you open it.
- Minimap button with a tooltip breakdown per character.

## Slash commands

| Command | Effect |
|---|---|
| `/eggtimer` | Print the current report |
| `/eggtimer scan` | Force a bag rescan, then report |
| `/eggtimer sound` | Toggle the ready chime |
| `/eggtimer minimap` | Toggle the minimap button |
| `/eggtimer reset` | Wipe all stored data |

`/egg` is a shorthand alias.

## History

The original **EggTimer** was written by **diocode** and **jokeyrhyme**, BSD
licensed, last released in 2010 for game version 3.3
([WowAce project](https://www.wowace.com/projects/eggtimer)). It detected items
by parsing loot chat messages, which never worked for these vendor-bought items,
and it has been abandoned since jokeyrhyme stopped playing in 2010.

**EggTimer Continued** is a ground-up reimplementation for current retail. It
shares no code with the original: different libraries, a bag-scan detection
model, account-wide storage. Only the name and the tracked-item list carry over.
Licensed MIT.

## Install

Install **EggTimer Continued** through CurseForge or your addon manager. To run
from source, drop the packaged `EggTimerContinued` folder into `Interface/AddOns`
(or `scripts/link.sh` to symlink this repo there for development).
