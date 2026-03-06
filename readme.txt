# AuralinGmMenu

AuralinGmMenu is a maintained revival of the original `gmMenu` addon for modern Retail World of Warcraft, with a Classic-ready architecture.

## Original Credits

Special thanks to the original `gmMenu` developers and maintainers:
- `gmarco` (original addon author)
- `Wexen` (credited maintainer/contributor on WoWInterface)

This project keeps their original design spirit while updating implementation details for current API and UI standards.

## License

The revived `AuralinGmMenu` project is distributed under the MIT License.

The original `gmMenu` BSD 3-Clause notice is preserved in `THIRD_PARTY_NOTICES.md`
to respect the licensing conditions that apply to inherited material and project
history.

If you redistribute source or binaries that include inherited material, keep the
original notice, conditions, and disclaimer with the distribution.

## What Was Modernized

- Addon rename and packaging identity: `AuralinGmMenu`
- SavedVariables migration:
  - Legacy: `GMMENU_CFG`
  - Current: `AuralinGmMenuDB`
- Removal of `loadstring` action execution
- Retail-first API wrappers with legacy fallbacks for Classic-readiness
- Updated micro-menu coverage:
  - Character
  - Spellbook/Talents (merged handling)
  - Professions
  - Achievements
  - Quest Log
  - Guild
  - Group Finder
  - Collections
  - Adventure Journal
  - Housing Dashboard (shown only when available on the client)
  - Main Menu / Reload UI
- Modern Settings panel registration (with fallback path)
- Optional minimap icon via `LibDBIcon-1.0`
- ElvUI and LDB bar compatibility focus (no direct microbar hooks)

## Commands

- `/agmm` opens addon settings
- `/auralingmmenu` opens addon settings
- `/agmm minimap` toggles minimap icon visibility
- `/agmm reload` reloads the UI

## CurseForge + GitHub Automated Releases

This project is set up for semantic-tag releases:

- Tag format: `vMAJOR.MINOR.PATCH`
- Example: `v1.0.0`

When a tag is pushed, GitHub Actions runs the BigWigs packager, builds the addon zip, and can upload to CurseForge.

### Required metadata/tokens

- TOC uses conditional packager tags:
  - Local/debug installs show `## Version: 0.0.0-dev`
  - Packaged releases populate `## Version: @project-version@`
- `.pkgmeta` uses `package-as: AuralinGmMenu`
- GitHub secret: `CF_API_KEY` (CurseForge upload key)
- GitHub token: `GITHUB_TOKEN` (provided automatically to Actions)

### Before first CurseForge publish

1. Create your new CurseForge project.
2. Update:
   - `AuralinGmMenu.toc` -> `## X-Curse-Project-ID: <your_project_id>`
   - `.pkgmeta` -> `curseforge.project-id: <your_project_id>`
3. Add `CF_API_KEY` in repo secrets.
4. Push a semantic tag (for example `v1.0.0`).

## Development Notes

- Retail target interface in TOC is `120001`.
- Compatibility fallback code exists for legacy API paths.
- The project is intentionally broker-based (LDB) plus optional minimap icon.

## Packaging Folder Name

Packaged output uses folder name: `AuralinGmMenu`.



