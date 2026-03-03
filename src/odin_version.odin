package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

current_odin_version :: proc() -> string {
    desc := os.Process_Desc{
        command = []string{"odin", "version"},
    }
    state, stdout, stderr, err := os.process_exec(desc, context.allocator)
    if err != nil || !state.exited || state.exit_code != 0 {
        delete(stdout)
        delete(stderr)
        return strings.clone("")
    }

    output := strings.trim_space(string(stdout))
    version := output
    if strings.has_prefix(output, "odin version ") {
        version = strings.trim_space(output[len("odin version "):])
    } else if strings.has_prefix(output, "Odin version ") {
        version = strings.trim_space(output[len("Odin version "):])
    }

    result := strings.clone(version)
    delete(stdout)
    delete(stderr)
    return result
}

warn_project_odin_version_mismatch :: proc(cfg: ^Config, current_odin: string) {
    if cfg == nil || cfg.odin_version == "" || current_odin == "" do return
    if cfg.odin_version == current_odin do return

    fmt.eprintln("Warning: Odin version mismatch for this project.")
    fmt.eprintln("  Project was created with:", cfg.odin_version)
    fmt.eprintln("  Current Odin version:   ", current_odin)
    fmt.eprintln("  Please review compatibility carefully; it may not run as expected.")
}

warn_package_odin_version_mismatch :: proc(pkg_name, pkg_path, current_odin: string) {
    if current_odin == "" do return

    sub_config_path, join_err := filepath.join([]string{pkg_path, CONFIG_FILE}, context.allocator)
    if join_err != nil do return
    defer delete(sub_config_path)

    if !os.exists(sub_config_path) do return

    sub_cfg, ok := read_config(sub_config_path)
    if !ok do return
    defer config_free(&sub_cfg)

    if sub_cfg.odin_version == "" || sub_cfg.odin_version == current_odin do return

    fmt.eprintln("Warning: Installed package", pkg_name, "was created with Odin", sub_cfg.odin_version)
    fmt.eprintln("  Current Odin version is ", current_odin)
    fmt.eprintln("  Please review compatibility carefully; it may not run as expected.")
}
