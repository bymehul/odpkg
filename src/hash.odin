package main

import "core:os"
import "core:strings"
import "core:path/filepath"
import "core:crypto/hash"
import "core:slice"
import "core:fmt"

// Computes a sha256 hash of all files in a directory.
// Files are sorted by name so the hash is reproducible.

compute_dir_hash :: proc(dir_path: string) -> string {
    files := collect_files(dir_path)
    if len(files) == 0 {
        delete(files)
        return strings.clone("")
    }
    defer {
        for f in files do delete(f)
        delete(files)
    }

    // sort so we always get the same hash regardless of filesystem order
    slice.sort(files[:])

    // build one big buffer with paths + contents, then hash it
    sb := strings.builder_make()
    defer strings.builder_destroy(&sb)

    for file_path in files {
        rel_path := make_relative(file_path, dir_path)
        strings.write_string(&sb, rel_path)
        delete(rel_path)

        data, ok := os.read_entire_file(file_path)
        if ok {
            strings.write_bytes(&sb, data)
            delete(data)
        }
    }

    content := strings.to_string(sb)
    digest := hash.hash(.SHA256, transmute([]u8)content)
    hex := bytes_to_hex(digest[:])
    return hex
}

collect_files :: proc(dir_path: string) -> [dynamic]string {
    files := make([dynamic]string)
    collect_files_recursive(dir_path, &files)
    return files
}

collect_files_recursive :: proc(dir_path: string, files: ^[dynamic]string) {
    handle, err := os.open(dir_path)
    if err != nil do return
    defer os.close(handle)

    entries, read_err := os.read_dir(handle, -1)
    if read_err != nil do return
    defer delete(entries)

    for entry in entries {
        // skip git internals
        if entry.name == ".git" do continue

        full_path, join_err := filepath.join([]string{dir_path, entry.name})
        if join_err != nil do continue

        if entry.is_dir {
            collect_files_recursive(full_path, files)
            delete(full_path)
        } else {
            append(files, full_path)
        }
    }
}

make_relative :: proc(path: string, base: string) -> string {
    if strings.has_prefix(path, base) {
        rel := path[len(base):]
        if len(rel) > 0 && (rel[0] == '/' || rel[0] == '\\') {
            rel = rel[1:]
        }
        return strings.clone(rel)
    }
    return strings.clone(path)
}

bytes_to_hex :: proc(data: []u8) -> string {
    hex_chars := "0123456789abcdef"
    result := make([]u8, len(data) * 2)
    for b, i in data {
        result[i*2]   = hex_chars[b >> 4]
        result[i*2+1] = hex_chars[b & 0x0F]
    }
    out := strings.clone(string(result[:]))
    delete(result)
    return out
}

verify_hash :: proc(dir_path: string, expected: string) -> bool {
    if expected == "" do return true

    computed := compute_dir_hash(dir_path)
    defer delete(computed)

    // strip "sha256:" prefix if present
    expected_clean := expected
    if strings.has_prefix(expected, "sha256:") {
        expected_clean = expected[7:]
    }

    return computed == expected_clean
}
