package main

import "core:testing"
import "core:strings"
import "core:path/filepath"
import "core:os"
import os2 "core:os/os2"

@(test)
parse_repo_spec_basic :: proc(t: ^testing.T) {
    repo, ref, ok := parse_repo_spec("github.com/odin-lang/Odin@v1.0.0")
    testing.expect(t, ok, "expected parse to succeed")
    testing.expect(t, repo == "odin-lang/Odin")
    testing.expect(t, ref == "v1.0.0")
}

@(test)
parse_repo_spec_short :: proc(t: ^testing.T) {
    repo, ref, ok := parse_repo_spec("owner/repo")
    testing.expect(t, ok)
    testing.expect(t, repo == "owner/repo")
    testing.expect(t, ref == "")
}

@(test)
parse_repo_spec_rejects_non_github :: proc(t: ^testing.T) {
    _, _, ok := parse_repo_spec("https://gitlab.com/owner/repo")
    testing.expect(t, !ok)
}

@(test)
parse_inline_dep_basic :: proc(t: ^testing.T) {
    repo, ref, ok := parse_inline_dep("{ repo = \"raysan5/raylib\", ref = \"v5.0\" }")
    testing.expect(t, ok)
    testing.expect(t, repo == "raysan5/raylib")
    testing.expect(t, ref == "v5.0")
}

@(test)
format_dep_spec_basic :: proc(t: ^testing.T) {
    dep := Dep{
        name = strings.clone("demo"),
        repo = strings.clone("odin-lang/Odin"),
        ref  = strings.clone(""),
    }
    defer {
        delete(dep.name)
        delete(dep.repo)
        delete(dep.ref)
    }

    spec := format_dep_spec(dep)
    defer delete(spec)
    testing.expect(t, spec == "github.com/odin-lang/Odin")
}

@(test)
config_roundtrip :: proc(t: ^testing.T) {
    tmp_dir, err := os2.make_directory_temp("", "odpkg_test_*", context.allocator)
    if err != nil {
        testing.fail_now(t, "failed to create temp dir")
    }
    defer {
        _ = os2.remove_all(tmp_dir)
        delete(tmp_dir)
    }

    cfg := Config{
        name = strings.clone("demo"),
        version = strings.clone("0.2.0"),
        vendor_dir = strings.clone("third_party"),
    }
    dep := Dep{
        name = strings.clone("raylib"),
        repo = strings.clone("raysan5/raylib"),
        ref  = strings.clone("v5.0"),
    }
    append(&cfg.deps, dep)
    defer config_free(&cfg)

    cfg_path, path_err := filepath.join([]string{tmp_dir, CONFIG_FILE})
    if path_err != nil {
        testing.fail_now(t, "failed to build config path")
    }
    defer delete(cfg_path)

    ok := write_config(cfg_path, cfg)
    testing.expect(t, ok)

    cfg2, ok2 := read_config(cfg_path)
    testing.expect(t, ok2)
    defer config_free(&cfg2)

    testing.expect(t, cfg2.name == "demo")
    testing.expect(t, cfg2.version == "0.2.0")
    testing.expect(t, cfg2.vendor_dir == "third_party")
    testing.expect(t, len(cfg2.deps) == 1)
    if len(cfg2.deps) == 1 {
        testing.expect(t, cfg2.deps[0].name == "raylib")
        testing.expect(t, cfg2.deps[0].repo == "raysan5/raylib")
        testing.expect(t, cfg2.deps[0].ref == "v5.0")
    }

    _ = os.remove(cfg_path)
}

@(test)
read_config_inline_dep :: proc(t: ^testing.T) {
    tmp_dir, err := os2.make_directory_temp("", "odpkg_test_*", context.allocator)
    if err != nil {
        testing.fail_now(t, "failed to create temp dir")
    }
    defer {
        _ = os2.remove_all(tmp_dir)
        delete(tmp_dir)
    }

    cfg_path, path_err := filepath.join([]string{tmp_dir, CONFIG_FILE})
    if path_err != nil {
        testing.fail_now(t, "failed to build config path")
    }
    defer delete(cfg_path)

    content := "[odpkg]\nname = \"demo\"\n\n[dependencies]\nraylib = { repo = \"raysan5/raylib\", ref = \"v5.0\" }\n"
    ok := os.write_entire_file(cfg_path, transmute([]u8)content)
    testing.expect(t, ok)

    cfg, ok2 := read_config(cfg_path)
    testing.expect(t, ok2)
    defer config_free(&cfg)

    testing.expect(t, len(cfg.deps) == 1)
    if len(cfg.deps) == 1 {
        testing.expect(t, cfg.deps[0].name == "raylib")
        testing.expect(t, cfg.deps[0].repo == "raysan5/raylib")
        testing.expect(t, cfg.deps[0].ref == "v5.0")
    }
}

@(test)
parse_registry_json_basic :: proc(t: ^testing.T) {
    data := "[{\"id\":1,\"slug\":\"tempo\",\"display_name\":\"tempo\",\"description\":\"templating\",\"type\":\"library\",\"status\":\"in_work\",\"repository_url\":\"https://github.com/kalsprite/tempo\",\"license\":\"BSD-3\"},{\"id\":2,\"slug\":\"odin-dbus\",\"display_name\":\"odin-dbus\",\"description\":\"dbus\",\"type\":\"library\",\"status\":\"ready\",\"repository_url\":\"https://github.com/A1029384756/odin-dbus\",\"license\":\"MIT\"}]"

    pkgs, ok := parse_registry_json(data)
    testing.expect(t, ok)
    testing.expect(t, len(pkgs) == 2)
    if len(pkgs) >= 1 {
        testing.expect(t, pkgs[0].slug == "tempo")
        testing.expect(t, pkgs[0].repository_url == "https://github.com/kalsprite/tempo")
        testing.expect(t, pkgs[0].status == "in_work")
    }
    if len(pkgs) >= 2 {
        testing.expect(t, pkgs[1].slug == "odin-dbus")
        testing.expect(t, pkgs[1].license == "MIT")
    }
    free_registry_packages(&pkgs)
}

// tests for v0.3.0 features

@(test)
bytes_to_hex_basic :: proc(t: ^testing.T) {
    data := []u8{0x00, 0x0f, 0xab, 0xff}
    hex := bytes_to_hex(data)
    defer delete(hex)
    testing.expect(t, hex == "000fabff")
}

@(test)
bytes_to_hex_empty :: proc(t: ^testing.T) {
    data := []u8{}
    hex := bytes_to_hex(data)
    defer delete(hex)
    testing.expect(t, hex == "")
}

@(test)
make_relative_basic :: proc(t: ^testing.T) {
    rel := make_relative("/home/user/project/file.txt", "/home/user/project")
    defer delete(rel)
    testing.expect(t, rel == "file.txt")
}

@(test)
make_relative_no_match :: proc(t: ^testing.T) {
    rel := make_relative("/other/path/file.txt", "/home/user")
    defer delete(rel)
    testing.expect(t, rel == "/other/path/file.txt")
}

@(test)
verify_hash_empty_expected :: proc(t: ^testing.T) {
    // empty expected should always pass
    ok := verify_hash("/nonexistent", "")
    testing.expect(t, ok)
}

@(test)
compute_dir_hash_deterministic :: proc(t: ^testing.T) {
    tmp1, err1 := os2.make_directory_temp("", "odpkg_hash_*", context.allocator)
    if err1 != nil {
        testing.fail_now(t, "failed to create temp dir")
    }
    defer {
        _ = os2.remove_all(tmp1)
        delete(tmp1)
    }

    file_a1, err_a1 := filepath.join([]string{tmp1, "a.txt"})
    if err_a1 != nil {
        testing.fail_now(t, "failed to build path")
    }
    file_b1, err_b1 := filepath.join([]string{tmp1, "b.txt"})
    if err_b1 != nil {
        delete(file_a1)
        testing.fail_now(t, "failed to build path")
    }

    beta := "beta"
    ok := os.write_entire_file(file_b1, transmute([]u8)beta)
    testing.expect(t, ok)
    alpha := "alpha"
    ok = os.write_entire_file(file_a1, transmute([]u8)alpha)
    testing.expect(t, ok)

    hash1 := compute_dir_hash(tmp1)
    testing.expect(t, hash1 != "")

    delete(file_a1)
    delete(file_b1)

    tmp2, err2 := os2.make_directory_temp("", "odpkg_hash_*", context.allocator)
    if err2 != nil {
        delete(hash1)
        testing.fail_now(t, "failed to create temp dir")
    }
    defer {
        _ = os2.remove_all(tmp2)
        delete(tmp2)
    }

    file_a2, err_a2 := filepath.join([]string{tmp2, "a.txt"})
    if err_a2 != nil {
        delete(hash1)
        testing.fail_now(t, "failed to build path")
    }
    file_b2, err_b2 := filepath.join([]string{tmp2, "b.txt"})
    if err_b2 != nil {
        delete(file_a2)
        delete(hash1)
        testing.fail_now(t, "failed to build path")
    }

    ok = os.write_entire_file(file_a2, transmute([]u8)alpha)
    testing.expect(t, ok)
    ok = os.write_entire_file(file_b2, transmute([]u8)beta)
    testing.expect(t, ok)

    hash2 := compute_dir_hash(tmp2)
    testing.expect(t, hash2 != "")
    testing.expect(t, hash1 == hash2)

    delete(file_a2)
    delete(file_b2)
    delete(hash1)
    delete(hash2)
}

@(test)
lock_roundtrip_with_hash :: proc(t: ^testing.T) {
    tmp_dir, err := os2.make_directory_temp("", "odpkg_test_*", context.allocator)
    if err != nil {
        testing.fail_now(t, "failed to create temp dir")
    }
    defer {
        _ = os2.remove_all(tmp_dir)
        delete(tmp_dir)
    }

    lock_path, path_err := filepath.join([]string{tmp_dir, LOCK_FILE})
    if path_err != nil {
        testing.fail_now(t, "failed to build lock path")
    }
    defer delete(lock_path)

    deps := []Resolved_Dep{
        {
            dep = Dep{
                name = strings.clone("raylib"),
                repo = strings.clone("raysan5/raylib"),
                ref  = strings.clone("v5.0"),
            },
            commit = strings.clone("abc1234"),
            hash   = strings.clone("sha256:deadbeef"),
        },
    }

    ok := write_lock(lock_path, deps)
    testing.expect(t, ok)

    read_deps, read_ok := read_lock(lock_path)
    testing.expect(t, read_ok)
    defer free_resolved_list(&read_deps)

    testing.expect(t, len(read_deps) == 1)
    if len(read_deps) == 1 {
        testing.expect(t, read_deps[0].dep.name == "raylib")
        testing.expect(t, read_deps[0].commit == "abc1234")
        testing.expect(t, read_deps[0].hash == "sha256:deadbeef")
    }

    // cleanup the test data
    delete(deps[0].dep.name)
    delete(deps[0].dep.repo)
    delete(deps[0].dep.ref)
    delete(deps[0].commit)
    delete(deps[0].hash)
}

@(test)
is_commit_hash_valid :: proc(t: ^testing.T) {
    testing.expect(t, is_commit_hash("abc123def"))
    testing.expect(t, is_commit_hash("0123456789abcdef0123456789abcdef01234567"))
}

@(test)
is_commit_hash_invalid :: proc(t: ^testing.T) {
    testing.expect(t, !is_commit_hash("v1.0.0"))  // tag format
    testing.expect(t, !is_commit_hash("main"))    // branch name
    testing.expect(t, !is_commit_hash("abc"))     // too short
    testing.expect(t, !is_commit_hash("xyz123"))  // invalid chars
}
