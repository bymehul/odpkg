# odpkg — Future Notes

## Known Constraints (v0.1)
- GitHub-only sources (no GitLab/Bitbucket/self-hosted yet).
- Vendoring-first installs into `vendor/` (no global cache).
- No subdir packages (repo root only).
- Minimal TOML parsing (only `[odpkg]` and `[dependencies]`, inline tables for deps).
- No checksum/verification yet.
- Lockfile is required for reproducible installs; do not edit `odpkg.lock` manually.
- No private repo auth flows yet.
