package main

import "core:os"
import "core:strings"

read_config :: proc(path: string) -> (Config, bool) {
    data, ok := os.read_entire_file(path)
    if !ok do return Config{}, false
    defer delete(data)

    cfg := Config{
        vendor_dir = strings.clone("vendor"),
    }

    lines, err := strings.split_lines(string(data))
    if err != nil {
        config_free(&cfg)
        return Config{}, false
    }
    defer delete(lines)

    section := ""
    for line in lines {
        trimmed := strings.trim_space(line)
        if trimmed == "" do continue
        if strings.has_prefix(trimmed, "#") do continue

        if idx := strings.index_byte(trimmed, '#'); idx >= 0 {
            trimmed = strings.trim_space(trimmed[:idx])
            if trimmed == "" do continue
        }

        if strings.has_prefix(trimmed, "[") && strings.has_suffix(trimmed, "]") {
            section = trimmed[1:len(trimmed)-1]
            continue
        }

        eq := strings.index_byte(trimmed, '=')
        if eq < 0 do continue
        key := strings.trim_space(trimmed[:eq])
        raw := strings.trim_space(trimmed[eq+1:])

        // We only care about [odpkg] and [dependencies].
        switch section {
        case "odpkg":
            value := trim_quotes(raw)
            switch key {
            case "name":
                cfg.name = strings.clone(value)
            case "version":
                cfg.version = strings.clone(value)
            case "vendor_dir":
                if value != "" {
                    delete(cfg.vendor_dir)
                    cfg.vendor_dir = strings.clone(value)
                }
            }
        case "dependencies":
            repo, ref, ok_dep := parse_dep_value(raw)
            if !ok_dep do continue
            dep := Dep{
                name = strings.clone(key),
                repo = strings.clone(repo),
                ref  = strings.clone(ref),
            }
            append(&cfg.deps, dep)
        }
    }

    return cfg, true
}

write_config :: proc(path: string, cfg: Config) -> bool {
    sb := strings.builder_make()
    defer strings.builder_destroy(&sb)

    strings.write_string(&sb, "[odpkg]\n")
    if cfg.name != "" {
        line := strings.concatenate({"name = \"", cfg.name, "\"\n"})
        strings.write_string(&sb, line)
        delete(line)
    }
    if cfg.version != "" {
        line := strings.concatenate({"version = \"", cfg.version, "\"\n"})
        strings.write_string(&sb, line)
        delete(line)
    }
    if cfg.vendor_dir != "" {
        line := strings.concatenate({"vendor_dir = \"", cfg.vendor_dir, "\"\n"})
        strings.write_string(&sb, line)
        delete(line)
    }
    strings.write_string(&sb, "\n[dependencies]\n")
    for dep in cfg.deps {
        if dep.ref != "" {
            line := strings.concatenate({dep.name, " = { repo = \"", dep.repo, "\", ref = \"", dep.ref, "\" }\n"})
            strings.write_string(&sb, line)
            delete(line)
        } else {
            line := strings.concatenate({dep.name, " = { repo = \"", dep.repo, "\" }\n"})
            strings.write_string(&sb, line)
            delete(line)
        }
    }

    content := strings.to_string(sb)
    ok := os.write_entire_file(path, transmute([]u8)content)
    return ok
}

parse_dep_value :: proc(raw: string) -> (repo, ref: string, ok: bool) {
    trimmed := strings.trim_space(raw)
    if strings.has_prefix(trimmed, "{") {
        return parse_inline_dep(trimmed)
    }
    value := trim_quotes(trimmed)
    return parse_repo_spec(value)
}

parse_inline_dep :: proc(raw: string) -> (repo, ref: string, ok: bool) {
    trimmed := strings.trim_space(raw)
    if !strings.has_prefix(trimmed, "{") || !strings.has_suffix(trimmed, "}") do return "", "", false

    inner := strings.trim_space(trimmed[1:len(trimmed)-1])
    if inner == "" do return "", "", false

    parts, err := strings.split(inner, ",")
    if err != nil do return "", "", false
    defer delete(parts)

    repo_val := ""
    ref_val := ""

    for part in parts {
        p := strings.trim_space(part)
        if p == "" do continue
        eq := strings.index_byte(p, '=')
        if eq < 0 do continue
        key := strings.trim_space(p[:eq])
        value := strings.trim_space(p[eq+1:])
        value = trim_quotes(value)

        switch key {
        case "repo":
            repo_val = value
        case "ref":
            ref_val = value
        }
    }

    if repo_val == "" do return "", "", false
    repo_norm, _, ok_repo := parse_repo_spec(repo_val)
    if !ok_repo do return "", "", false

    return repo_norm, ref_val, true
}

parse_repo_spec :: proc(spec: string) -> (repo, ref: string, ok: bool) {
    s := strings.trim_space(spec)
    if s == "" do return "", "", false

    if strings.has_prefix(s, "https://github.com/") {
        s = s[len("https://github.com/"):]
    } else if strings.has_prefix(s, "http://github.com/") {
        s = s[len("http://github.com/"):]
    } else if strings.has_prefix(s, "github.com/") {
        s = s[len("github.com/"):]
    } else if strings.contains(s, "://") {
        return "", "", false
    }

    at := strings.index_byte(s, '@')
    if at >= 0 {
        ref = s[at+1:]
        s = s[:at]
    }

    if strings.has_suffix(s, ".git") {
        s = s[:len(s)-4]
    }

    if !strings.contains(s, "/") {
        return "", "", false
    }

    return s, ref, true
}

format_dep_spec :: proc(dep: Dep) -> string {
    base := strings.concatenate({"github.com/", dep.repo})
    if dep.ref == "" {
        return base
    }
    spec := strings.concatenate({base, "@", dep.ref})
    delete(base)
    return spec
}

repo_name_from :: proc(repo: string) -> string {
    idx := strings.last_index_byte(repo, '/')
    if idx < 0 || idx+1 >= len(repo) do return repo
    return repo[idx+1:]
}

trim_quotes :: proc(s: string) -> string {
    if len(s) >= 2 {
        if (s[0] == '"' && s[len(s)-1] == '"') || (s[0] == '\'' && s[len(s)-1] == '\'') {
            return s[1:len(s)-1]
        }
    }
    return s
}

dep_index :: proc(deps: []Dep, name: string) -> int {
    for d, i in deps {
        if d.name == name do return i
    }
    return -1
}

config_free :: proc(cfg: ^Config) {
    if cfg == nil do return
    if cfg.name != "" do delete(cfg.name)
    if cfg.version != "" do delete(cfg.version)
    if cfg.vendor_dir != "" do delete(cfg.vendor_dir)
    for dep in cfg.deps {
        if dep.name != "" do delete(dep.name)
        if dep.repo != "" do delete(dep.repo)
        if dep.ref != "" do delete(dep.ref)
    }
    delete(cfg.deps)
}
