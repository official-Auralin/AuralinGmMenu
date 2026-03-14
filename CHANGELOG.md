# Changelog

All notable changes to this project are documented in this file.

The format follows Keep a Changelog and this project uses semantic versioning.

## [Unreleased]

## [v1.0.2] - 2026-03-14

### Fixed

- Broker tooltip now stays interactive when moving the cursor from the launcher onto the tooltip, matching the intended hover-to-click menu behavior.

### Changed

- Hover and left click now open the same LibQTip tooltip instead of splitting behavior across two different menu surfaces.
- Removed the old popup-frame menu path in favor of a single interactive tooltip.
- Addon monitoring and memory diagnostics now render in that shared tooltip.
- Updated tooltip help text and localized strings to reflect the new single-tooltip behavior.

## [v1.0.1] - 2026-03-06

### Changed

- Set the CurseForge project ID in `.pkgmeta` and `AuralinGmMenu.toc`.

## [v1.0.0] - 2026-03-06

### Added

- Initial Retail revival release of `AuralinGmMenu`.
- LDB broker launcher, optional minimap icon, modern settings panel, localization scaffolding, and release packaging setup.
