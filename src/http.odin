package main

import "core:net"
import "core:strings"
import "core:fmt"
import "core:strconv"
import c "core:c/libc"
import "base:runtime"
import curl "vendor:curl"

// HTTP client
// - HTTP: native core:net
// - HTTPS: libcurl (vendor:curl)

Http_Buffer :: struct {
    sb: strings.Builder,
}

curl_initialized := false

http_get :: proc(url: string) -> (string, bool) {
    if strings.has_prefix(url, "https://") {
        data, ok := http_get_curl(url)
        if !ok {
            fmt.eprintln("HTTPS fetch failed.")
            fmt.eprintln("  Hint: Ensure libcurl is installed on your system")
            return strings.clone(""), false
        }
        return data, true
    }

    if strings.has_prefix(url, "http://") {
        return http_get_native(url)
    }

    fmt.eprintln("Unsupported URL scheme:", url)
    return strings.clone(""), false
}

curl_init_once :: proc() -> bool {
    if curl_initialized do return true
    if curl.global_init(curl.GLOBAL_DEFAULT) != curl.code.E_OK {
        fmt.eprintln("Failed to initialize libcurl")
        return false
    }
    curl_initialized = true
    return true
}

http_write_cb :: proc "c" (buffer: [^]byte, size: c.size_t, nitems: c.size_t, outstream: rawptr) -> c.size_t {
    context = runtime.default_context()
    if outstream == nil do return 0
    total := size * nitems
    if total == 0 do return 0

    buf := (^Http_Buffer)(outstream)
    count := int(total)
    strings.write_bytes(&buf.sb, buffer[:count])
    return total
}

http_get_curl :: proc(url: string) -> (string, bool) {
    if !curl_init_once() {
        return strings.clone(""), false
    }

    handle := curl.easy_init()
    if handle == nil {
        fmt.eprintln("Failed to create curl handle")
        return strings.clone(""), false
    }
    defer curl.easy_cleanup(handle)

    ua := strings.concatenate({"odpkg/", VERSION})
    defer delete(ua)

    buf := Http_Buffer{sb = strings.builder_make()}
    defer strings.builder_destroy(&buf.sb)

    url_cstr, err_url := strings.clone_to_cstring(url, context.temp_allocator)
    if err_url != nil {
        fmt.eprintln("Failed to allocate URL")
        return strings.clone(""), false
    }
    ua_cstr, err_ua := strings.clone_to_cstring(ua, context.temp_allocator)
    if err_ua != nil {
        fmt.eprintln("Failed to allocate User-Agent")
        return strings.clone(""), false
    }

    _ = curl.easy_setopt(handle, curl.option.URL, url_cstr)
    _ = curl.easy_setopt(handle, curl.option.USERAGENT, ua_cstr)
    _ = curl.easy_setopt(handle, curl.option.FOLLOWLOCATION, c.long(1))
    _ = curl.easy_setopt(handle, curl.option.SSL_VERIFYPEER, c.long(1))
    _ = curl.easy_setopt(handle, curl.option.SSL_VERIFYHOST, c.long(2))
    _ = curl.easy_setopt(handle, curl.option.WRITEFUNCTION, http_write_cb)
    _ = curl.easy_setopt(handle, curl.option.WRITEDATA, &buf)

    res := curl.easy_perform(handle)
    if res != curl.code.E_OK {
        fmt.eprintln("curl error:", curl.easy_strerror(res))
        return strings.clone(""), false
    }

    status: c.long
    _ = curl.easy_getinfo(handle, curl.INFO.RESPONSE_CODE, &status)
    if status < 200 || status >= 300 {
        fmt.eprintln("HTTP error:", status)
        return strings.clone(""), false
    }

    out := strings.to_string(buf.sb)
    return out, true
}

http_get_native :: proc(url: string) -> (string, bool) {
    host, path, port, ok := parse_http_url(url)
    if !ok {
        fmt.eprintln("Failed to parse URL:", url)
        return strings.clone(""), false
    }

    // resolve hostname to ip4 endpoint
    host_with_port := strings.concatenate({host, ":", fmt.tprint(port)})
    defer delete(host_with_port)

    endpoint, resolve_err := net.resolve_ip4(host_with_port)
    if resolve_err != nil {
        fmt.eprintln("DNS resolution failed for:", host)
        fmt.eprintln("  Error:", resolve_err)
        return strings.clone(""), false
    }

    // connect via tcp
    socket, dial_err := net.dial_tcp(endpoint)
    if dial_err != nil {
        fmt.eprintln("Failed to connect to:", host)
        fmt.eprintln("  Error:", dial_err)
        return strings.clone(""), false
    }
    defer net.close(socket)

    // build http request
    ua := strings.concatenate({"odpkg/", VERSION})
    defer delete(ua)
    req := strings.concatenate({
        "GET ", path, " HTTP/1.1\r\n",
        "Host: ", host, "\r\n",
        "Connection: close\r\n",
        "User-Agent: ", ua, "\r\n",
        "\r\n",
    })
    defer delete(req)

    // send request
    _, send_err := net.send_tcp(socket, transmute([]u8)req)
    if send_err != nil {
        fmt.eprintln("Failed to send request")
        return strings.clone(""), false
    }

    // read response
    response := strings.builder_make()
    defer strings.builder_destroy(&response)

    buf: [4096]u8
    for {
        bytes_read, recv_err := net.recv_tcp(socket, buf[:])
        if recv_err != nil {
            break
        }
        if bytes_read == 0 {
            break
        }
        strings.write_bytes(&response, buf[:bytes_read])
    }

    full := strings.to_string(response)
    defer delete(full)

    // parse status line
    status_end := strings.index(full, "\r\n")
    if status_end >= 0 {
        status_line := full[:status_end]
        first_sp := strings.index(status_line, " ")
        if first_sp >= 0 {
            rest := status_line[first_sp + 1:]
            second_sp := strings.index(rest, " ")
            code_str := rest
            if second_sp >= 0 {
                code_str = rest[:second_sp]
            }
            status, ok_status := strconv.parse_int(code_str)
            if ok_status && (status < 200 || status >= 300) {
                fmt.eprintln("HTTP error:", status)
                return strings.clone(""), false
            }
        }
    }

    // parse response - find body after \r\n\r\n
    body_start := strings.index(full, "\r\n\r\n")
    if body_start < 0 {
        return strings.clone(""), false
    }

    body := full[body_start + 4:]

    // check for chunked encoding
    if strings.contains(full[:body_start], "Transfer-Encoding: chunked") {
        return decode_chunked(body)
    }

    return strings.clone(body), true
}

parse_http_url :: proc(url: string) -> (host, path: string, port: int, ok: bool) {
    // strip protocol
    remaining := url
    if strings.has_prefix(url, "https://") {
        remaining = url[8:]
        port = 443
    } else if strings.has_prefix(url, "http://") {
        remaining = url[7:]
        port = 80
    } else {
        return "", "", 0, false
    }

    // split host and path
    slash_idx := strings.index(remaining, "/")
    if slash_idx < 0 {
        host = remaining
        path = "/"
    } else {
        host = remaining[:slash_idx]
        path = remaining[slash_idx:]
    }

    // check for port in host
    colon_idx := strings.index(host, ":")
    if colon_idx >= 0 {
        port_str := host[colon_idx + 1:]
        host = host[:colon_idx]
        parsed_port, parse_ok := strconv.parse_int(port_str)
        if parse_ok {
            port = parsed_port
        }
    }

    ok = len(host) > 0
    return
}

decode_chunked :: proc(data: string) -> (string, bool) {
    result := strings.builder_make()
    defer strings.builder_destroy(&result)

    remaining := data
    for len(remaining) > 0 {
        // find chunk size line
        line_end := strings.index(remaining, "\r\n")
        if line_end < 0 do break

        size_str := remaining[:line_end]
        chunk_size, parse_ok := strconv.parse_int(size_str, 16)
        if !parse_ok do break
        if chunk_size == 0 do break

        remaining = remaining[line_end + 2:]
        if len(remaining) < chunk_size do break

        strings.write_string(&result, remaining[:chunk_size])
        remaining = remaining[chunk_size:]

        // skip trailing \r\n
        if len(remaining) >= 2 && remaining[:2] == "\r\n" {
            remaining = remaining[2:]
        }
    }

    return strings.to_string(result), true
}
