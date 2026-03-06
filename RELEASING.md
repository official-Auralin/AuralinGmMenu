# Releasing AuralinGmMenu

## One-Time Setup

1. Create a CurseForge project.
2. Replace placeholder project IDs:
   - `AuralinGmMenu.toc`: `## X-Curse-Project-ID: 000000`
   - `.pkgmeta`: `curseforge.project-id: 000000`
3. Add repository secret:
   - `CF_API_KEY` = your CurseForge API token

## Versioning

- Use semantic tags only:
  - `vMAJOR.MINOR.PATCH`
  - Example: `v1.0.0`

## Release Flow (GitHub Primary)

1. Merge release-ready changes into `main`.
2. Create and push a tag:
   - `git tag v1.0.0`
   - `git push origin v1.0.0`
3. GitHub Actions workflow `.github/workflows/release.yml` packages and publishes.

## CurseForge Webhook Fallback

If GitHub Actions is unavailable, you can keep CurseForge webhook packaging configured as backup.
The same `.pkgmeta` and TOC token strategy is compatible with both workflows.

## TOC Versioning

- Local debug installs use ## Version: 0.0.0-dev.
- Packaged releases replace the TOC version with @project-version@ via packager build tags.

