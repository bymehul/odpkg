package main

import "core:fmt"
import "core:strings"
import os2 "core:os/os2"

clone_dep :: proc(dep: Dep, dest: string) -> bool {
    url := format_clone_url(dep.repo)
    // No ref means follow the default branch.
    if dep.ref == "" {
        ok := run_cmd([]string{"git", "clone", url, dest}, "")
        delete(url)
        return ok
    }

    // Commit hashes need a full clone (depth=1 won't reliably fetch).
    if is_commit_hash(dep.ref) {
        ok := run_cmd([]string{"git", "clone", url, dest}, "")
        if ok {
            _ = run_cmd([]string{"git", "-C", dest, "checkout", dep.ref}, "")
        }
        delete(url)
        return ok
    }

    // Tags/branches are safe to shallow clone.
    ok := run_cmd([]string{"git", "clone", "--depth", "1", "--branch", dep.ref, url, dest}, "")
    if ok {
        delete(url)
        return true
    }

    _ = os2.remove_all(dest)
    ok = run_cmd([]string{"git", "clone", url, dest}, "")
    if ok {
        _ = run_cmd([]string{"git", "-C", dest, "checkout", dep.ref}, "")
    }
    delete(url)
    return ok
}

update_dep :: proc(dep: Dep, path: string) {
    if dep.ref == "" {
        _ = run_cmd([]string{"git", "-C", path, "pull", "--ff-only"}, "")
        return
    }
    if is_commit_hash(dep.ref) {
        // Fetch all and checkout the exact commit.
        _ = run_cmd([]string{"git", "-C", path, "fetch", "--all", "--tags"}, "")
        _ = run_cmd([]string{"git", "-C", path, "checkout", dep.ref}, "")
        return
    }

    // For tags/branches, checkout then fast-forward.
    _ = run_cmd([]string{"git", "-C", path, "fetch", "--tags"}, "")
    _ = run_cmd([]string{"git", "-C", path, "checkout", dep.ref}, "")
    _ = run_cmd([]string{"git", "-C", path, "pull", "--ff-only"}, "")
}

ensure_dep_at_commit :: proc(repo: string, dest: string, commit: string) -> bool {
    url := format_clone_url(repo)
    ok := run_cmd([]string{"git", "clone", url, dest}, "")
    if ok {
        _ = run_cmd([]string{"git", "-C", dest, "checkout", commit}, "")
        delete(url)
        return true
    }
    delete(url)
    return false
}

update_dep_to_commit :: proc(dest: string, commit: string) -> bool {
    _ = run_cmd([]string{"git", "-C", dest, "fetch", "--all", "--tags"}, "")
    return run_cmd([]string{"git", "-C", dest, "checkout", commit}, "")
}

run_cmd :: proc(args: []string, cwd: string) -> bool {
    desc := os2.Process_Desc{
        command = args,
        working_dir = cwd,
    }
    state, stdout, stderr, err := os2.process_exec(desc, context.allocator)
    if err != nil {
        fmt.eprintln("Process error:", err)
        if len(stdout) > 0 {
            fmt.print(string(stdout))
        }
        if len(stderr) > 0 {
            fmt.eprintln(string(stderr))
        }
        delete(stdout)
        delete(stderr)
        return false
    }

    if len(stdout) > 0 {
        fmt.print(string(stdout))
    }
    if len(stderr) > 0 {
        fmt.eprintln(string(stderr))
    }
    delete(stdout)
    delete(stderr)
    return state.exited && state.exit_code == 0
}

git_rev_parse :: proc(path: string) -> string {
    desc := os2.Process_Desc{
        command = []string{"git", "-C", path, "rev-parse", "HEAD"},
    }
    state, stdout, stderr, err := os2.process_exec(desc, context.allocator)
    if err != nil || !state.exited || state.exit_code != 0 {
        if len(stderr) > 0 {
            fmt.eprintln(string(stderr))
        }
        delete(stdout)
        delete(stderr)
        return strings.clone("")
    }
    out := strings.trim_space(string(stdout))
    res := strings.clone(out)
    delete(stdout)
    delete(stderr)
    return res
}

format_clone_url :: proc(repo: string) -> string {
    return strings.concatenate({"https://github.com/", repo, ".git"})
}

is_commit_hash :: proc(ref: string) -> bool {
    if len(ref) < 7 || len(ref) > 40 do return false
    for i := 0; i < len(ref); i += 1 {
        c := ref[i]
        if (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F') {
            continue
        }
        return false
    }
    return true
}
