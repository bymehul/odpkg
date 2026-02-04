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
