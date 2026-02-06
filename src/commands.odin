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
        version = strings.clone("0.2.0"),
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
        fmt.eprintln("       odpkg add --registry <slug> [alias]")
        return
    }

    // Check for --registry flag.
    registry_mode := false
    slug := ""
    alias := ""
    repo_spec := ""

    i := 0
    for i < len(args) {
        if args[i] == "--registry" {
            registry_mode = true
            i += 1
            if i < len(args) {
                slug = args[i]
                i += 1
            }
        } else if repo_spec == "" {
            repo_spec = args[i]
            i += 1
        } else if alias == "" {
            alias = args[i]
            i += 1
        } else {
            i += 1
        }
    }

    repo := ""
    ref := ""

    if registry_mode {
        if slug == "" {
            fmt.eprintln("Usage: odpkg add --registry <slug> [alias]")
            return
        }
        // Lookup slug in registry.
        pkg, found := find_registry_package(slug, false)
        if !found {
            fmt.eprintln("Package not found in registry:", slug)
            fmt.eprintln("  Hint: Try 'odpkg list --registry --refresh' to update cache")
            return
        }
        defer {
            if pkg.slug != "" do delete(pkg.slug)
            if pkg.display_name != "" do delete(pkg.display_name)
            if pkg.description != "" do delete(pkg.description)
            if pkg.type != "" do delete(pkg.type)
            if pkg.status != "" do delete(pkg.status)
            if pkg.repository_url != "" do delete(pkg.repository_url)
            if pkg.license != "" do delete(pkg.license)
        }

        // Extract repo from repository_url.
        parsed_repo, parsed_ref, ok := parse_repo_spec(pkg.repository_url)
        if !ok {
            fmt.eprintln("Invalid repository URL in registry:", pkg.repository_url)
            return
        }
        repo = parsed_repo
        ref = parsed_ref
        if alias == "" {
            alias = slug
        }
    } else {
        if repo_spec == "" {
            fmt.eprintln("Usage: odpkg add <repo[@ref]> [alias]")
            return
        }
        parsed_repo, parsed_ref, ok := parse_repo_spec(repo_spec)
        if !ok {
            fmt.eprintln("Invalid repo spec. Use owner/repo or github.com/owner/repo.")
            fmt.eprintln("  Example: odpkg add github.com/odin-lang/Odin@v1.0.0")
            return
        }
        repo = parsed_repo
        ref = parsed_ref
    }

    if alias == "" {
        alias = repo_name_from(repo)
    }

    if !is_safe_dep_name(alias) {
        fmt.eprintln("Invalid dependency name/alias:", alias)
        fmt.eprintln("  Hint: Use a simple name without spaces or path separators")
        return
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

cmd_search :: proc(args: []string) {
    if len(args) < 1 {
        fmt.eprintln("Usage: odpkg search <query>")
        return
    }

    query := args[0]
    refresh := false

    for i := 1; i < len(args); i += 1 {
        if args[i] == "--refresh" {
            refresh = true
        }
    }

    search_registry_packages(query, refresh)
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

cmd_list :: proc(args: []string) {
    list_registry := false
    list_deps := false
    refresh := false

    for arg in args {
        switch arg {
        case "--registry":
            list_registry = true
        case "--deps":
            list_deps = true
        case "--refresh":
            refresh = true
        }
    }

    if list_registry && list_deps {
        fmt.eprintln("Use only one of --registry or --deps.")
        return
    }

    if list_registry {
        list_registry_packages(refresh)
        return
    }

    cfg, ok_cfg := read_config(CONFIG_FILE)
    if !ok_cfg {
        // No local config; fall back to registry list.
        list_registry_packages(refresh)
        return
    }
    defer config_free(&cfg)

    if list_deps || len(cfg.deps) > 0 {
        if len(cfg.deps) == 0 {
            fmt.println("No dependencies.")
            return
        }
        for dep in cfg.deps {
            spec := format_dep_spec(dep)
            fmt.printf("%s = %s\n", dep.name, spec)
            delete(spec)
        }
        return
    }

    // Default to registry list when nothing local is defined.
    list_registry_packages(refresh)
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

    if !is_safe_vendor_dir(cfg.vendor_dir) {
        fmt.eprintln("Invalid vendor_dir in odpkg.toml:", cfg.vendor_dir)
        fmt.eprintln("  Hint: Use a relative path like \"vendor\"")
        return
    }

    _ = os2.make_directory_all(cfg.vendor_dir)

    // Prefer lockfile for reproducible installs when available.
    if os.exists(LOCK_FILE) {
        lock_deps, lock_ok := read_lock(LOCK_FILE)
        if !lock_ok {
            fmt.eprintln("Invalid odpkg.lock. Refusing to install.")
            return
        }
        if len(lock_deps) > 0 {
            defer free_resolved_list(&lock_deps)
            install_from_lock(cfg.vendor_dir, lock_deps[:])
            return
        }
    }

    // Fresh install re-resolves refs from odpkg.toml.
    resolved := make([dynamic]Resolved_Dep)
    defer free_resolved_list(&resolved)

    installed := make(map[string]bool)
    defer delete(installed)

    install_deps_recursive(cfg.deps[:], cfg.vendor_dir, &resolved, &installed, 0)

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

    if !is_safe_vendor_dir(cfg.vendor_dir) {
        fmt.eprintln("Invalid vendor_dir in odpkg.toml:", cfg.vendor_dir)
        fmt.eprintln("  Hint: Use a relative path like \"vendor\"")
        return
    }

    _ = os2.make_directory_all(cfg.vendor_dir)

    resolved := make([dynamic]Resolved_Dep)
    defer free_resolved_list(&resolved)

    installed := make(map[string]bool)
    defer delete(installed)

    for dep in cfg.deps {
        if !is_safe_dep_name(dep.name) {
            fmt.eprintln("Invalid dependency name:", dep.name)
            continue
        }
        path, ok_path := safe_vendor_path(cfg.vendor_dir, dep.name)
        if !ok_path do continue

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
        pkg_hash := compute_dir_hash(path)
        r := Resolved_Dep{
            dep = Dep{
                name = strings.clone(dep.name),
                repo = strings.clone(dep.repo),
                ref  = strings.clone(dep.ref),
            },
            commit = strings.clone(commit),
            hash   = strings.concatenate({"sha256:", pkg_hash}),
        }
        delete(commit)
        delete(pkg_hash)
        installed[dep.name] = true

        // Check for transitive dependencies.
        check_transitive_deps(path, cfg.vendor_dir, &resolved, &installed, 1)

        delete(path)
        append(&resolved, r)
    }

    if len(resolved) > 0 {
        _ = write_lock(LOCK_FILE, resolved[:])
    }
}

// Install dependencies recursively, handling transitive deps.
install_deps_recursive :: proc(deps: []Dep, vendor_dir: string, resolved: ^[dynamic]Resolved_Dep, installed: ^map[string]bool, depth: int) {
    if depth > 10 {
        fmt.eprintln("Warning: Maximum dependency depth reached (possible cycle)")
        return
    }

    for dep in deps {
        if dep.name in installed^ do continue

        if !is_safe_dep_name(dep.name) {
            fmt.eprintln("Invalid dependency name:", dep.name)
            continue
        }
        path, ok_path := safe_vendor_path(vendor_dir, dep.name)
        if !ok_path do continue

        if os.exists(path) && os.is_dir(path) {
            fmt.println("Exists:", dep.name)
        } else {
            if !clone_dep(dep, path) {
                fmt.eprintln("Failed to install:", dep.name)
                delete(path)
                continue
            }
            fmt.println("Installed:", dep.name)
        }

        commit := git_rev_parse(path)
        pkg_hash := compute_dir_hash(path)
        r := Resolved_Dep{
            dep = Dep{
                name = strings.clone(dep.name),
                repo = strings.clone(dep.repo),
                ref  = strings.clone(dep.ref),
            },
            commit = strings.clone(commit),
            hash   = strings.concatenate({"sha256:", pkg_hash}),
        }
        delete(commit)
        delete(pkg_hash)
        installed^[dep.name] = true
        append(resolved, r)

        // Check for transitive dependencies.
        check_transitive_deps(path, vendor_dir, resolved, installed, depth + 1)

        delete(path)
    }
}

// Check if installed package has its own odpkg.toml and install those deps.
check_transitive_deps :: proc(pkg_path: string, vendor_dir: string, resolved: ^[dynamic]Resolved_Dep, installed: ^map[string]bool, depth: int) {
    sub_config_path, join_err := filepath.join([]string{pkg_path, CONFIG_FILE})
    if join_err != nil do return
    defer delete(sub_config_path)

    if !os.exists(sub_config_path) do return

    sub_cfg, ok := read_config(sub_config_path)
    if !ok do return
    defer config_free(&sub_cfg)

    if len(sub_cfg.deps) > 0 {
        base_name := filepath.base(pkg_path)
        fmt.println("  Found transitive deps in:", base_name)
        install_deps_recursive(sub_cfg.deps[:], vendor_dir, resolved, installed, depth)
    }
}

install_from_lock :: proc(vendor_dir: string, deps: []Resolved_Dep) {
    for item in deps {
        if !is_safe_dep_name(item.dep.name) {
            fmt.eprintln("Invalid dependency name in lockfile:", item.dep.name)
            continue
        }
        path, ok_path := safe_vendor_path(vendor_dir, item.dep.name)
        if !ok_path do continue

        if os.exists(path) && os.is_dir(path) {
            if !update_dep_to_commit(path, item.commit) {
                fmt.eprintln("Failed to checkout:", item.dep.name)
            }
        } else {
            if !ensure_dep_at_commit(item.dep.repo, path, item.commit) {
                fmt.eprintln("Failed to install:", item.dep.name)
                delete(path)
                continue
            }
        }

        actual := git_rev_parse(path)
        if actual == "" || actual != item.commit {
            fmt.eprintln("Commit mismatch for", item.dep.name)
            fmt.eprintln("  Expected:", item.commit)
            fmt.eprintln("  Actual:  ", actual)
            delete(actual)
            delete(path)
            continue
        }
        delete(actual)

        // Verify hash after checkout/clone.
        if item.hash != "" {
            if !verify_hash(path, item.hash) {
                fmt.eprintln("Warning: Hash mismatch for", item.dep.name)
                fmt.eprintln("  Expected:", item.hash)
                fmt.eprintln("  Hint: Run 'odpkg update' to refresh")
            }
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
        if r.hash != "" do delete(r.hash)
    }
    delete(list^)
}
