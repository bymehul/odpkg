# odpkg Documentation

odpkg is an **unofficial** Odin package manager focused on simplicity and vendoring. It installs dependencies into a local `vendor/` folder and keeps a lockfile for reproducible builds.

## Quick Start

```bash
odpkg init
odpkg add github.com/owner/repo@v1.0.0
odpkg install
```

## Requirements

- `git` in PATH
- `curl` in PATH (used for registry list)

## Commands

```bash
odpkg init [name]
odpkg add <repo[@ref]> [alias]
odpkg remove <alias>
odpkg install
odpkg update
odpkg list [--registry | --deps] [--refresh]
odpkg version
```

## Command Behavior

- `odpkg init` creates `odpkg.toml` in the current folder.
- `odpkg add` adds or updates a dependency entry in `odpkg.toml`.
- `odpkg remove` removes a dependency by alias name.
- `odpkg install` installs into `vendor/` and writes `odpkg.lock`.
- `odpkg update` re-resolves refs and updates `odpkg.lock`.
- `odpkg list` defaults to registry output when no local deps exist.
- `odpkg list --deps` forces local deps output from `odpkg.toml`.
- `odpkg list --registry` forces registry output.
- `odpkg list --registry --refresh` re-fetches registry data.

## Config File (`odpkg.toml`)

```toml
[odpkg]
name = "my-project"
version = "0.2.0"
vendor_dir = "vendor"

[dependencies]
raylib = { repo = "raysan5/raylib", ref = "v5.0" }
```

## Dependency Syntax

Preferred (structured):

```toml
[dependencies]
raylib = { repo = "raysan5/raylib", ref = "v5.0" }
```

Short form (accepted):

```toml
[dependencies]
raylib = "github.com/raysan5/raylib@v5.0"
```

Notes:
- `repo` can be `owner/repo`, `github.com/owner/repo`, or a full `https://` URL.
- `ref` can be a tag, branch, or commit hash.

## Alias Resolution

Order of alias resolution:
1. Explicit alias argument in `odpkg add`
2. Dependency key name in `odpkg.toml`
3. Repo name (last path segment)

## Lockfile (`odpkg.lock`)

- Records exact commit hashes for every dependency.
- Must **not** be edited manually.
- Used automatically by `odpkg install` when present.

## Install vs Update

- `odpkg install` uses `odpkg.lock` if present, otherwise resolves from `odpkg.toml`.
- `odpkg update` re-resolves refs and updates `odpkg.lock`.

## Registry List

The registry is fetched from:

```
https://api.pkg-odin.org/packages
```

Registry data is cached in your OS cache directory:
- Linux: `~/.cache/odpkg/packages.json`
- macOS: `~/Library/Caches/odpkg/packages.json`
- Windows: `%LOCALAPPDATA%\odpkg\packages.json`

## Examples

Add a dependency:

```bash
odpkg add github.com/kalsprite/tempo
```

Install all deps:

```bash
odpkg install
```

List registry packages:

```bash
odpkg list --registry
```

Force refresh:

```bash
odpkg list --registry --refresh
```

## Known Constraints (v0.1)

- GitHub-only sources (no GitLab/Bitbucket/self-hosted yet).
- Vendoring-first installs into `vendor/` (no global cache).
- No subdir packages (repo root only).
- Minimal TOML parsing.
- No checksum/verification yet.
- No private repo auth flows yet.

## Troubleshooting

- If `odpkg list --registry` fails, ensure `curl` is installed and in PATH.
- If `odpkg install` fails, verify `git` is installed and the repo URL is correct.

## License

odpkg is licensed under the zlib License.
