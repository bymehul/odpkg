# odpkg

An **unofficial** open-source package manager for Odin. It is vendor-first and keeps installs local to `vendor/`.

Principles:
- GitHub-only (v0.1)
- Vendoring-first

## Quick Start

```bash
odpkg init
odpkg add github.com/owner/repo@v1.0.0
odpkg install
```

## Install (Build From Source)

```bash
git clone https://github.com/bymehul/odpkg
cd odpkg
odin build src -out:odpkg
./odpkg --help
```

## Install (Prebuilt Binary)

Linux/macOS:

```bash
VERSION=v0.2.0
ASSET=odpkg-ubuntu-latest
curl -L -o odpkg "https://github.com/bymehul/odpkg/releases/download/${VERSION}/${ASSET}"
chmod +x odpkg
./odpkg --help
```

Windows (PowerShell):

```powershell
$version = "v0.2.0"
$asset = "odpkg-windows-latest.exe"
Invoke-WebRequest -Uri "https://github.com/bymehul/odpkg/releases/download/$version/$asset" -OutFile "odpkg.exe"
.\odpkg.exe --help
```

## Add To PATH

Linux/macOS (current session):

```bash
export PATH="$PWD:$PATH"
```

Linux/macOS (permanent):

```bash
mkdir -p "$HOME/.local/bin"
mv odpkg "$HOME/.local/bin/odpkg"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

Windows (PowerShell, current session):

```powershell
$env:Path = "$PWD;" + $env:Path
```

Windows (permanent, PowerShell):

```powershell
[Environment]::SetEnvironmentVariable("Path", "$env:Path;$PWD", "User")
```

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

## Registry List

`odpkg list --registry` fetches the public registry and caches it.  
This uses `curl` under the hood, so make sure `curl` is in PATH.

## Docs

See `docs.md` for full usage, config format, registry details, and troubleshooting.

## License

Licensed under the zlib License.
