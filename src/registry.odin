package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:path/filepath"
import os2 "core:os/os2"
import json "core:encoding/json"

RegistryPackage :: struct {
    id:             int,
    slug:           string,
    display_name:   string,
    description:    string,
    type:           string,
    status:         string,
    repository_url: string,
    license:        string,
}

list_registry_packages :: proc(refresh: bool) {
    cache_file := registry_cache_path()
    if cache_file == "" {
        fmt.eprintln("Unable to locate a cache directory.")
        return
    }
    defer delete(cache_file)

    data := ""
    if !refresh {
        cached, ok := read_cached_registry(cache_file)
        if ok {
            data = cached
        }
    }

    if data == "" {
        fetched, ok := fetch_registry()
        if !ok {
            fmt.eprintln("Failed to fetch registry.")
            return
        }
        data = fetched
        _ = write_registry_cache(cache_file, data)
    }

    packages, ok := parse_registry_json(data)
    delete(data)
    if !ok {
        fmt.eprintln("Failed to parse registry data.")
        return
    }

    if len(packages) == 0 {
        fmt.println("No packages found.")
        delete(packages)
        return
    }

    for pkg in packages {
        fmt.printf("%s | %s | %s\n", pkg.slug, pkg.repository_url, pkg.status)
    }

    free_registry_packages(&packages)
}

registry_cache_path :: proc() -> string {
    cache_dir, err := os2.user_cache_dir(context.allocator)
    if err != nil || cache_dir == "" {
        return strings.clone("")
    }

    base, err1 := filepath.join([]string{cache_dir, "odpkg"})
    if err1 != nil {
        delete(cache_dir)
        return strings.clone("")
    }
    _ = os2.make_directory_all(base)
    delete(cache_dir)

    path, err2 := filepath.join([]string{base, "packages.json"})
    delete(base)
    if err2 != nil {
        return strings.clone("")
    }
    return path
}

read_cached_registry :: proc(path: string) -> (string, bool) {
    data, ok := os.read_entire_file(path)
    if !ok do return "", false
    text := strings.clone(string(data))
    delete(data)
    return text, true
}

write_registry_cache :: proc(path: string, payload: string) -> bool {
    return os.write_entire_file(path, transmute([]u8)payload)
}

fetch_registry :: proc() -> (string, bool) {
    if !curl_available() {
        fmt.eprintln("curl was not found in PATH. Please install curl and retry.")
        return strings.clone(""), false
    }
    cmd := []string{"curl", "-fsSL", "https://api.pkg-odin.org/packages"}
    out, ok := run_cmd_capture(cmd, "")
    return out, ok
}

run_cmd_capture :: proc(args: []string, cwd: string) -> (string, bool) {
    desc := os2.Process_Desc{
        command = args,
        working_dir = cwd,
    }
    state, stdout, stderr, err := os2.process_exec(desc, context.allocator)
    if err != nil || !state.exited || state.exit_code != 0 {
        if len(stderr) > 0 {
            fmt.eprintln(string(stderr))
        }
        delete(stdout)
        delete(stderr)
        return strings.clone(""), false
    }

    out := strings.clone(string(stdout))
    delete(stdout)
    delete(stderr)
    return out, true
}

curl_available :: proc() -> bool {
    desc := os2.Process_Desc{
        command = []string{"curl", "--version"},
    }
    state, stdout, stderr, err := os2.process_exec(desc, context.allocator)
    delete(stdout)
    delete(stderr)
    if err != nil {
        return false
    }
    return state.exited && state.exit_code == 0
}

parse_registry_json :: proc(data: string) -> ([dynamic]RegistryPackage, bool) {
    packages := make([dynamic]RegistryPackage)
    if err := json.unmarshal_string(data, &packages); err != nil {
        delete(packages)
        return make([dynamic]RegistryPackage), false
    }
    return packages, true
}

free_registry_packages :: proc(list: ^[dynamic]RegistryPackage) {
    if list == nil do return
    for pkg in list^ {
        if pkg.slug != "" do delete(pkg.slug)
        if pkg.display_name != "" do delete(pkg.display_name)
        if pkg.description != "" do delete(pkg.description)
        if pkg.type != "" do delete(pkg.type)
        if pkg.status != "" do delete(pkg.status)
        if pkg.repository_url != "" do delete(pkg.repository_url)
        if pkg.license != "" do delete(pkg.license)
    }
    delete(list^)
}
