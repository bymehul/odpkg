package main

VERSION     :: "0.4.0"
CONFIG_FILE :: "odpkg.toml"
LOCK_FILE   :: "odpkg.lock"

Dep :: struct {
    name: string,
    repo: string,
    ref:  string,
}

Config :: struct {
    name:       string,
    version:    string,
    vendor_dir: string,
    deps:       [dynamic]Dep,
}

Resolved_Dep :: struct {
    dep:    Dep,
    commit: string,
    hash:   string,
}
