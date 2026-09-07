# Changelog

## 1.0.0

First release. A ground-up reimplementation of the abandoned 2010 EggTimer for
current retail.

- Tracks Mysterious Egg and Disgusting Jar across every character on the account.
- Detects state by scanning bags, so "ready to open" is always correct rather
  than a guessed clock.
- On login, and within ~30s if it happens while you are playing, a chat line and
  an optional chime tell you which character has something to collect.
- Minimap button with a per-character tooltip breakdown.
- `/eggtimer` slash command (`/egg` alias) for a report and options.
