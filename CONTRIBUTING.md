# Contributing

## Local Development

1. Clone the repository into your WoW addon directory (or symlink it).
2. Ensure the addon folder name is `AuralinGmMenu` for in-game texture path consistency.
3. Use `/reload` in game after changes.

## Coding Guidelines

- Keep code Retail-first with compatibility fallbacks for Classic-ready support.
- Avoid direct hooks into Blizzard microbars or third-party action bar frames.
- Keep LDB behavior stable for broker addons (ElvUI, ChocolateBar, Titan Panel, etc).

## Pull Requests

1. Describe behavior changes and compatibility impact.
2. Note any API assumptions (Retail-only vs fallback behavior).
3. Include test notes (in-game checks performed).
