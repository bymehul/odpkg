# odpkg

An **unofficial** open-source package manager for Odin.

Principles:
- GitHub-only
- Vendoring-first

## Dependency Syntax

Structured form (preferred):

```toml
[dependencies]
raylib = { repo = "raysan5/raylib", ref = "v5.0" }
```

Short string form (accepted):

```toml
[dependencies]
raylib = "github.com/raysan5/raylib@v5.0"
```

Both forms are normalized internally to the structured form.

## Alias Resolution

Order of alias resolution:
1. Explicit alias argument in `odpkg add`
2. Dependency key name in `odpkg.toml`
3. Repo name (last path segment)

## Config

`odpkg.toml`:

```toml
[odpkg]
name = "my-project"
version = "0.1.0"
vendor_dir = "vendor"

[dependencies]
raylib = { repo = "raysan5/raylib", ref = "v5.0" }
```

Dependency values accept:
- `owner/repo`
- `github.com/owner/repo`
- `https://github.com/owner/repo`
- Optional `@ref` (tag/branch/commit)

## Commands

```bash
odpkg init [name]
odpkg add <repo[@ref]> [alias]
odpkg remove <alias>
odpkg install
odpkg update
odpkg list
```

## Install Behavior

- Installs into `vendor/<alias>`
- Uses `git clone` (depth=1 for tags/branches, full clone for commits)
- `odpkg.lock` records the exact commit hash for every dependency and must not be edited manually

## Install vs Update

- `odpkg install` uses `odpkg.lock` if present. Otherwise it resolves from `odpkg.toml` and writes a new lockfile.
- `odpkg update` re-resolves refs from `odpkg.toml` and updates `odpkg.lock`.

## Download and Use (Windows, macOS, Linux)

Clone from GitHub (all platforms):

```bash
git clone https://github.com/bymehul/odpkg
cd odpkg
```

Build and run (macOS/Linux):

```bash
odin build src -out:odpkg
./odpkg --help
```

Build and run (Windows PowerShell):

```powershell
odin build src -out:odpkg.exe
.\odpkg.exe --help
```

Optional install to PATH (macOS/Linux):

```bash
mkdir -p ~/.local/bin
mv ./odpkg ~/.local/bin/
```

Optional install to PATH (Windows):
Add the folder containing `odpkg.exe` to PATH using System Environment Variables.

## Install From Release (Quick)

macOS:

```bash
VERSION=v0.1.0
ASSET=odpkg-macos-latest
curl -L -o odpkg "https://github.com/bymehul/odpkg/releases/download/${VERSION}/${ASSET}"
chmod +x odpkg
./odpkg --help
```

Linux:

```bash
VERSION=v0.1.0
ASSET=odpkg-ubuntu-latest
curl -L -o odpkg "https://github.com/bymehul/odpkg/releases/download/${VERSION}/${ASSET}"
chmod +x odpkg
./odpkg --help
```

Windows (PowerShell):

```powershell
$version = "v0.1.0"
$asset = "odpkg-windows-latest.exe"
Invoke-WebRequest -Uri "https://github.com/bymehul/odpkg/releases/download/$version/$asset" -OutFile "odpkg.exe"
.\odpkg.exe --help
```

## Build

```bash
odin build src -out:odpkg
```

## Tests

```bash
odin test src
```

## License

Licensed under the zlib License, to align with Odin’s own licensing.
