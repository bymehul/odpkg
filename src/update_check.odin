package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:strconv"

check_for_updates_notice :: proc() {
    latest, ok := fetch_latest_odpkg_version()
    if !ok do return
    defer delete(latest)

    if !version_is_newer(latest, VERSION) do return

    current_tag := normalize_version_tag(VERSION)
    defer delete(current_tag)

    fmt.eprintln("Update available:", latest, "(current:", current_tag, ")")
    fmt.eprintln("  Download the latest release from: https://github.com/bymehul/odpkg/releases")
}

fetch_latest_odpkg_version :: proc() -> (string, bool) {
    desc := os.Process_Desc{
        command = []string{
            "git",
            "ls-remote",
            "--tags",
            "--refs",
            "https://github.com/bymehul/odpkg.git",
        },
    }

    state, stdout, stderr, err := os.process_exec(desc, context.allocator)
    delete(stderr)
    if err != nil || !state.exited || state.exit_code != 0 {
        delete(stdout)
        return strings.clone(""), false
    }
    defer delete(stdout)

    lines, split_err := strings.split_lines(string(stdout))
    if split_err != nil {
        return strings.clone(""), false
    }
    defer delete(lines)

    has_best := false
    best_major := 0
    best_minor := 0
    best_patch := 0

    for line in lines {
        trimmed := strings.trim_space(line)
        if trimmed == "" do continue

        idx := strings.index(trimmed, "refs/tags/")
        if idx < 0 do continue

        tag := strings.trim_space(trimmed[idx+len("refs/tags/"):])
        major, minor, patch, ok := parse_version_triplet(tag)
        if !ok do continue

        if !has_best || is_triplet_newer(major, minor, patch, best_major, best_minor, best_patch) {
            has_best = true
            best_major = major
            best_minor = minor
            best_patch = patch
        }
    }

    if !has_best {
        return strings.clone(""), false
    }

    return format_version_tag(best_major, best_minor, best_patch), true
}

version_is_newer :: proc(latest, current: string) -> bool {
    latest_major, latest_minor, latest_patch, latest_ok := parse_version_triplet(latest)
    if !latest_ok do return false

    cur_major, cur_minor, cur_patch, cur_ok := parse_version_triplet(current)
    if !cur_ok do return false

    return is_triplet_newer(latest_major, latest_minor, latest_patch, cur_major, cur_minor, cur_patch)
}

is_triplet_newer :: proc(a_major, a_minor, a_patch, b_major, b_minor, b_patch: int) -> bool {
    if a_major != b_major do return a_major > b_major
    if a_minor != b_minor do return a_minor > b_minor
    return a_patch > b_patch
}

parse_version_triplet :: proc(version: string) -> (major, minor, patch: int, ok: bool) {
    s := strings.trim_space(version)
    if s == "" do return 0, 0, 0, false

    if strings.has_prefix(s, "v") || strings.has_prefix(s, "V") {
        s = s[1:]
    }
    if s == "" do return 0, 0, 0, false

    if dash := strings.index_byte(s, '-'); dash >= 0 {
        s = s[:dash]
    }

    parts, split_err := strings.split(s, ".")
    if split_err != nil {
        return 0, 0, 0, false
    }
    defer delete(parts)

    if len(parts) != 3 do return 0, 0, 0, false

    major_val, major_ok := strconv.parse_int(parts[0])
    minor_val, minor_ok := strconv.parse_int(parts[1])
    patch_val, patch_ok := strconv.parse_int(parts[2])
    if !major_ok || !minor_ok || !patch_ok {
        return 0, 0, 0, false
    }
    if major_val < 0 || minor_val < 0 || patch_val < 0 {
        return 0, 0, 0, false
    }

    return major_val, minor_val, patch_val, true
}

normalize_version_tag :: proc(version: string) -> string {
    s := strings.trim_space(version)
    if s == "" do return strings.clone("")

    if strings.has_prefix(s, "v") {
        return strings.clone(s)
    }
    if strings.has_prefix(s, "V") {
        return strings.concatenate({"v", s[1:]})
    }
    return strings.concatenate({"v", s})
}

format_version_tag :: proc(major, minor, patch: int) -> string {
    major_s := fmt.tprint(major)
    minor_s := fmt.tprint(minor)
    patch_s := fmt.tprint(patch)
    return strings.concatenate({"v", major_s, ".", minor_s, ".", patch_s})
}
