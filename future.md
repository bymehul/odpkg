# odpkg — Future Notes

## Known Constraints (v0.1)
- GitHub-only sources (no GitLab/Bitbucket/self-hosted yet).
- Vendoring-first installs into `vendor/` (no global cache).
- No subdir packages (repo root only).
- Minimal TOML parsing (only `[odpkg]` and `[dependencies]`, inline tables for deps).
- No checksum/verification yet.
- Lockfile is required for reproducible installs; do not edit `odpkg.lock` manually.
- No private repo auth flows yet.
- Registry list is cached in the OS cache directory (use `--refresh` to re-fetch).

## Why GitHub-only (v0.1)
Keeping GitHub-only avoids early complexity around URL formats, auth flows, and host-specific metadata.
The goal is a small, predictable core before expanding to more hosts.

## Planned (Post v0.1)
- Native HTTP fetcher so registry access does not depend on `curl`.
- Registry search/filter and `odpkg add --registry <slug>`.
- Checksums and integrity verification.
- Optional global cache (in addition to vendoring).
- Subdir packages and monorepo support.
- Non-GitHub hosts (GitLab, Bitbucket, Codeberg, self-hosted).
- Private repo auth (token/SSH).
