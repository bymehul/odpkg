package main

import "core:fmt"
import "core:os"

main :: proc() {
    args := os.args
    if len(args) < 2 {
        print_usage()
        return
    }

    cmd := args[1]
    switch cmd {
    case "help", "-h", "--help":
        print_usage()
    case "version", "-v", "--version":
        fmt.println("odpkg", VERSION)
    case "init":
        cmd_init(args[2:])
    case "add":
        cmd_add(args[2:])
    case "remove", "rm":
        cmd_remove(args[2:])
    case "install":
        cmd_install()
    case "update":
        cmd_update()
    case "list", "ls":
        cmd_list(args[2:])
    case "search":
        cmd_search(args[2:])
    case:
        fmt.eprintln("Unknown command:", cmd)
        print_usage()
    }
}

print_usage :: proc() {
    fmt.println("odpkg - Unofficial Odin package manager")
    fmt.println("")
    fmt.println("Usage:")
    fmt.println("  odpkg init [name]")
    fmt.println("  odpkg add <repo[@ref]> [alias]")
    fmt.println("  odpkg add --registry <slug> [alias]")
    fmt.println("  odpkg remove <alias>")
    fmt.println("  odpkg install")
    fmt.println("  odpkg update")
    fmt.println("  odpkg list [--registry | --deps] [--refresh]")
    fmt.println("  odpkg search <query> [--refresh]")
    fmt.println("  odpkg version")
    fmt.println("")
    fmt.println("Notes:")
    fmt.println("  - GitHub-only")
    fmt.println("  - Vendoring-first (installs into vendor/)")
}
