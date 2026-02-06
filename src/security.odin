package main

import "core:strings"
import "core:path/filepath"

is_safe_dep_name :: proc(name: string) -> bool {
    if name == "" do return false
    if name == "." || name == ".." do return false
    if strings.contains_any(name, "/\\") do return false
    if strings.contains(name, ":") do return false
    if strings.contains_any(name, " \t\r\n") do return false
    return true
}

is_safe_vendor_dir :: proc(dir: string) -> bool {
    if dir == "" do return false
    if filepath.is_abs(dir) do return false
    if strings.contains_any(dir, "\t\r\n") do return false

    clean, err := filepath.clean(dir)
    if err != nil do return false
    defer delete(clean)

    if clean == "." || clean == ".." do return false
    if strings.has_prefix(clean, "../") || strings.has_prefix(clean, "..\\") do return false
    return true
}

safe_vendor_path :: proc(vendor_dir, name: string) -> (string, bool) {
    if !is_safe_vendor_dir(vendor_dir) || !is_safe_dep_name(name) {
        return "", false
    }

    joined, err := filepath.join([]string{vendor_dir, name})
    if err != nil {
        return "", false
    }

    clean_vendor, err2 := filepath.clean(vendor_dir)
    if err2 != nil {
        delete(joined)
        return "", false
    }

    rel, rel_err := filepath.rel(clean_vendor, joined)
    delete(clean_vendor)
    if rel_err != .None {
        delete(joined)
        return "", false
    }
    defer delete(rel)

    if rel == ".." || strings.has_prefix(rel, "../") || strings.has_prefix(rel, "..\\") {
        delete(joined)
        return "", false
    }

    return joined, true
}

is_safe_repo_value :: proc(s: string) -> bool {
    if s == "" do return false
    if strings.contains_any(s, " \t\r\n") do return false
    if strings.contains(s, "\\") do return false
    return true
}
