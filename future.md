# odpkg — Future Notes

## Known Constraints (v0.5.1)
- GitHub-only sources (no GitLab/Bitbucket/self-hosted yet).
- Vendoring-first installs into `vendor/` (no global cache).
- No subdir packages (repo root only).
- Minimal TOML parsing (only `[odpkg]` and `[dependencies]`, inline tables for deps).
- Lockfile is required for reproducible installs; do not edit `odpkg.lock` manually.
- No private repo auth flows yet.

## Completed in v0.3.x
- HTTP via `core:net` with libcurl for HTTPS registry fetches.
- Registry search/filter (`odpkg search <query>`).
- Add from registry (`odpkg add --registry <slug>`).
- Checksum/integrity verification (SHA256 hashes in lockfile).
- Transitive dependency support (auto-install nested deps).
- Better error messages with hints.

## Completed in v0.5.1
- HTTPS certificate verification enforced via libcurl options.
- Path traversal protection for dependency installs.
- Lockfile commit validation and checkout verification.

## Planned (Post v0.5.1)
- Optional global cache (in addition to vendoring).
- Subdir packages and monorepo support.
- Non-GitHub hosts (GitLab, Bitbucket, Codeberg, self-hosted).
- Private repo auth (token/SSH).
