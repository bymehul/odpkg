package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:path/filepath"
import os2 "core:os/os2"

cmd_init :: proc(args: []string) {
    if os.exists(CONFIG_FILE) {
        fmt.eprintln("odpkg.toml already exists.")
        return
    }

    name := ""
    if len(args) > 0 {
        name = strings.clone(args[0])
    } else {
        cwd, err := os2.get_working_directory(context.allocator)
        if err == nil {
            base := filepath.base(cwd)
            name = strings.clone(base)
            delete(cwd)
        } else {
            name = strings.clone("my-project")
        }
    }

    cfg := Config{
        name = name,
        version = strings.clone("0.1.0"),
        vendor_dir = strings.clone("vendor"),
    }
    defer config_free(&cfg)

    if !write_config(CONFIG_FILE, cfg) {
        fmt.eprintln("Failed to write odpkg.toml.")
        return
    }

    _ = os2.make_directory_all(cfg.vendor_dir)
    fmt.println("Initialized", CONFIG_FILE)
}

cmd_add :: proc(args: []string) {
    if len(args) < 1 {
        fmt.eprintln("Usage: odpkg add <repo[@ref]> [alias]")
        return
    }

    repo_spec := args[0]
    alias := ""
    if len(args) > 1 {
        alias = args[1]
    }

    repo, ref, ok_repo := parse_repo_spec(repo_spec)
    if !ok_repo {
        fmt.eprintln("Invalid repo spec. Use owner/repo or github.com/owner/repo.")
        return
    }

    if alias == "" {
        alias = repo_name_from(repo)
    }

    cfg, ok_cfg := read_config(CONFIG_FILE)
    if !ok_cfg {
        fmt.eprintln("Missing odpkg.toml. Run 'odpkg init' first.")
        return
    }
    defer config_free(&cfg)

    idx := dep_index(cfg.deps[:], alias)
    if idx >= 0 {
        delete(cfg.deps[idx].repo)
        delete(cfg.deps[idx].ref)
        cfg.deps[idx].repo = strings.clone(repo)
        cfg.deps[idx].ref = strings.clone(ref)
    } else {
        dep := Dep{
            name = strings.clone(alias),
            repo = strings.clone(repo),
            ref  = strings.clone(ref),
        }
        append(&cfg.deps, dep)
    }

    if !write_config(CONFIG_FILE, cfg) {
        fmt.eprintln("Failed to update odpkg.toml.")
        return
    }

    fmt.println("Added", alias)
}

cmd_remove :: proc(args: []string) {
    if len(args) < 1 {
        fmt.eprintln("Usage: odpkg remove <alias>")
        return
    }
    name := args[0]

    cfg, ok_cfg := read_config(CONFIG_FILE)
    if !ok_cfg {
        fmt.eprintln("Missing odpkg.toml. Run 'odpkg init' first.")
        return
    }
    defer config_free(&cfg)

    idx := dep_index(cfg.deps[:], name)
    if idx < 0 {
        fmt.eprintln("Dependency not found:", name)
        return
    }

    delete(cfg.deps[idx].name)
    delete(cfg.deps[idx].repo)
    delete(cfg.deps[idx].ref)
    last := len(cfg.deps) - 1
    cfg.deps[idx] = cfg.deps[last]
    resize(&cfg.deps, last)

    if !write_config(CONFIG_FILE, cfg) {
        fmt.eprintln("Failed to update odpkg.toml.")
        return
    }

    fmt.println("Removed", name)
}

cmd_list :: proc() {
    cfg, ok_cfg := read_config(CONFIG_FILE)
    if !ok_cfg {
        fmt.eprintln("Missing odpkg.toml. Run 'odpkg init' first.")
        return
    }
    defer config_free(&cfg)

    if len(cfg.deps) == 0 {
        fmt.println("No dependencies.")
        return
    }

    for dep in cfg.deps {
        spec := format_dep_spec(dep)
        fmt.printf("%s = %s\n", dep.name, spec)
        delete(spec)
    }
}

cmd_install :: proc() {
    cfg, ok_cfg := read_config(CONFIG_FILE)
    if !ok_cfg {
        fmt.eprintln("Missing odpkg.toml. Run 'odpkg init' first.")
        return
    }
    defer config_free(&cfg)

    if cfg.vendor_dir == "" {
        cfg.vendor_dir = strings.clone("vendor")
    }

    _ = os2.make_directory_all(cfg.vendor_dir)

    // Prefer lockfile for reproducible installs when available.
    lock_deps, lock_ok := read_lock(LOCK_FILE)
    if lock_ok && len(lock_deps) > 0 {
        defer free_resolved_list(&lock_deps)
        install_from_lock(cfg.vendor_dir, lock_deps[:])
        return
    }

    // Update always re-resolves refs from odpkg.toml.
    resolved := make([dynamic]Resolved_Dep)
    defer free_resolved_list(&resolved)

    for dep in cfg.deps {
        path := filepath.join([]string{cfg.vendor_dir, dep.name}) or_continue

        if os.exists(path) && os.is_dir(path) {
            fmt.println("Exists:", dep.name)
        } else {
            if !clone_dep(dep, path) {
                fmt.eprintln("Failed to install:", dep.name)
                delete(path)
                continue
            }
        }

        commit := git_rev_parse(path)
        r := Resolved_Dep{
            dep = Dep{
                name = strings.clone(dep.name),
                repo = strings.clone(dep.repo),
                ref  = strings.clone(dep.ref),
            },
            commit = strings.clone(commit),
        }
        delete(commit)
        delete(path)
        append(&resolved, r)
    }

    if len(resolved) > 0 {
        _ = write_lock(LOCK_FILE, resolved[:])
    }
}

cmd_update :: proc() {
    cfg, ok_cfg := read_config(CONFIG_FILE)
    if !ok_cfg {
        fmt.eprintln("Missing odpkg.toml. Run 'odpkg init' first.")
        return
    }
    defer config_free(&cfg)

    if cfg.vendor_dir == "" {
        cfg.vendor_dir = strings.clone("vendor")
    }

    _ = os2.make_directory_all(cfg.vendor_dir)

    resolved := make([dynamic]Resolved_Dep)
    defer free_resolved_list(&resolved)

    for dep in cfg.deps {
        path := filepath.join([]string{cfg.vendor_dir, dep.name}) or_continue

        if !os.exists(path) || !os.is_dir(path) {
            fmt.println("Missing:", dep.name, "(installing)")
            if !clone_dep(dep, path) {
                fmt.eprintln("Failed to install:", dep.name)
                delete(path)
                continue
            }
        } else {
            update_dep(dep, path)
        }

        commit := git_rev_parse(path)
        r := Resolved_Dep{
            dep = Dep{
                name = strings.clone(dep.name),
                repo = strings.clone(dep.repo),
                ref  = strings.clone(dep.ref),
            },
            commit = strings.clone(commit),
        }
        delete(commit)
        delete(path)
        append(&resolved, r)
    }

    if len(resolved) > 0 {
        _ = write_lock(LOCK_FILE, resolved[:])
    }
}

install_from_lock :: proc(vendor_dir: string, deps: []Resolved_Dep) {
    for item in deps {
        path := filepath.join([]string{vendor_dir, item.dep.name}) or_continue

        if os.exists(path) && os.is_dir(path) {
            if !update_dep_to_commit(path, item.commit) {
                fmt.eprintln("Failed to checkout:", item.dep.name)
            }
            delete(path)
            continue
        }

        if !ensure_dep_at_commit(item.dep.repo, path, item.commit) {
            fmt.eprintln("Failed to install:", item.dep.name)
        }
        delete(path)
    }
}

free_resolved_list :: proc(list: ^[dynamic]Resolved_Dep) {
    if list == nil do return
    for r in list^ {
        if r.dep.name != "" do delete(r.dep.name)
        if r.dep.repo != "" do delete(r.dep.repo)
        if r.dep.ref != "" do delete(r.dep.ref)
        if r.commit != "" do delete(r.commit)
    }
    delete(list^)
}
