package main

import "core:net"
import "core:strings"
import "core:fmt"
import "core:strconv"

// native http client using odin's core:net
// uses net.resolve_ip4() for dns and tcp sockets for http/1.1*

http_get :: proc(url: string) -> (string, bool) {
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
    req := strings.concatenate({
        "GET ", path, " HTTP/1.1\r\n",
        "Host: ", host, "\r\n",
        "Connection: close\r\n",
        "User-Agent: odpkg/0.3\r\n",
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
