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
    data, ok := http_get("https://api.pkg-odin.org/packages")
    if !ok {
        fmt.eprintln("Failed to fetch registry from api.pkg-odin.org")
        fmt.eprintln("  Hint: Check your network connection or ensure libcurl is installed")
        return strings.clone(""), false
    }
    return data, true
}

// Search registry packages by query string.
// Matches against slug, display_name, and description.
search_registry_packages :: proc(query: string, refresh: bool) {
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
        free_registry_packages(&packages)
        return
    }

    query_lower := strings.to_lower(query, context.temp_allocator)
    found := 0

    for pkg in packages {
        slug_lower := strings.to_lower(pkg.slug, context.temp_allocator)
        name_lower := strings.to_lower(pkg.display_name, context.temp_allocator)
        desc_lower := strings.to_lower(pkg.description, context.temp_allocator)

        if strings.contains(slug_lower, query_lower) ||
           strings.contains(name_lower, query_lower) ||
           strings.contains(desc_lower, query_lower) {
            fmt.printf("%s | %s | %s\n", pkg.slug, pkg.repository_url, pkg.status)
            found += 1
        }
    }

    if found == 0 {
        fmt.println("No packages matching:", query)
    }

    free_registry_packages(&packages)
}

// Find a package by slug in the registry.
find_registry_package :: proc(slug: string, refresh: bool) -> (RegistryPackage, bool) {
    cache_file := registry_cache_path()
    if cache_file == "" {
        return RegistryPackage{}, false
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
            return RegistryPackage{}, false
        }
        data = fetched
        _ = write_registry_cache(cache_file, data)
    }

    packages, ok := parse_registry_json(data)
    delete(data)
    if !ok {
        return RegistryPackage{}, false
    }

    for pkg in packages {
        if pkg.slug == slug {
            // Clone the package before freeing the list.
            result := RegistryPackage{
                id             = pkg.id,
                slug           = strings.clone(pkg.slug),
                display_name   = strings.clone(pkg.display_name),
                description    = strings.clone(pkg.description),
                type           = strings.clone(pkg.type),
                status         = strings.clone(pkg.status),
                repository_url = strings.clone(pkg.repository_url),
                license        = strings.clone(pkg.license),
            }
            free_registry_packages(&packages)
            return result, true
        }
    }

    free_registry_packages(&packages)
    return RegistryPackage{}, false
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
