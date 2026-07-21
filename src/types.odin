package main

VERSION     :: "0.6.4"
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
    odin_version: string,
    vendor_dir: string,
    deps:       [dynamic]Dep,
    ignores:    map[string][dynamic]string,
}

Resolved_Dep :: struct {
    dep:    Dep,
    commit: string,
    hash:   string,
}
