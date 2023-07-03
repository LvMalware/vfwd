module socks5

import os
import net

pub enum AuthType {
    no_auth_required        = 0
    gssapi                  = 1
    username_password       = 2
    // ... other IANA-assigned methods
    no_acceptable_methods   = 255
}

pub enum RequestType {
    connect       = 0x01
    bind          = 0x02
    udp_associate = 0x03
}

pub enum AddressType {
    ipv4    = 0x01
    domain  = 0x03
    ipv6    = 0x04
}

pub struct SocksAuth {
pub:
    atype AuthType
    // a map of username -> password (for now, this is the only auth method supported)
    users map[string] string
}

pub struct SocksServer {
pub:
    lport int = 1080
    lhost string
mut:
    auth     SocksAuth
    listener net.TcpListener
}

pub struct SocksClient {
pub:
    auth SocksAuth
mut:
    client &net.TcpConn
}

struct SocksRequest {
pub:
    ver     u8
    cmd     RequestType
    rsv     u8
    atyp    AddressType
    addr    string
    port    u16
}

pub fn copy_stream(mut src &net.TcpConn, mut dest &net.TcpConn)! {
    mut b := u8(0)
    for {
        src.read_ptr(&b, 1)!
        dest.write_ptr(&b, 1)!
    }
}

fn (r SocksRequest) do(mut client &net.TcpConn)! {
    match r.cmd {
        .connect {
            // eprintln("Connecting to $r.addr:$r.port")
            mut conn := net.dial_tcp("$r.addr:$r.port") or {
                client.write([u8(0x5), 0x03, 0x00, 0x01, 0x7f, 0x00, 0x00, 0x01, 0x00, 0x00])!
                return error("Failed to connect: $err")
            }

            defer {
                conn.close() or {}
            }

            client.write([u8(0x5), 0x00, 0x00, 0x01, 0x7f, 0x00, 0x00, 0x01, 0x00, 0x00])!

            go copy_stream(mut client, mut conn)
            copy_stream(mut conn, mut client)!

        } .bind {
            return error("Not implemented yet")
        } .udp_associate {
            return error("Not implemented yet")
        }
    }
}

pub fn (a SocksAuth) authenticate(mut client &net.TcpConn)! {
    mut buf := []u8{len: 256}
    client.read(mut buf[..2])!
    if buf[0] != 0x05 {
        return error("Wrong protocol version: ${buf[0].hex()}")
    }

    nmethods := int(buf[1])
    // eprintln("Client supports $nmethods auth methods:")
    client.read(mut buf[..nmethods])!

    /*
    for i in 0 .. nmethods {
        eprintln("Method $i: ${buf[i].hex()}")
    }
    */

    if u8(a.atype) !in buf[..nmethods] {
        client.write([u8(0x05), 0xff])!
        return error("Auth methods not supported")
    }

    match a.atype {
        .no_auth_required {
            client.write([u8(0x05), 0x00])!
            // nothing else to do
        } .username_password {
            // RFC 1929
            client.write([u8(0x05), 0x02])!
            client.read(mut buf[..2])!
            if buf[0] != 0x01 { return error("Auth method mismatch") }
            ulen := int(buf[1])
            client.read(mut buf[..ulen])!
            username := buf[..ulen].bytestr()
            client.read(mut buf[..1])!
            plen := int(buf[0])
            client.read(mut buf[..plen])!
            password := buf[..plen].bytestr()
            // eprintln("Client is trying to authenticate as $username:$password")
            if username !in a.users {
                client.write([u8(0x02), 0x01])!
                return error("User $username not found")
            }

            if password != a.users[username] {
                client.write([u8(0x02), 0x02])!
                return error("Wrong password for user $username")
            }
            client.write([u8(0x02), 0x00])!
        } else {
            // TODO: implement GSSAPI authentication for complience with RFC 1928
            client.write([u8(0x05), 0xff])!
            return error("Auth method ${a.atype} not implemented yet")
        }
    }
}

pub fn (mut c SocksClient) read_request() !SocksRequest {
    mut buf := []u8{len: 256}
    c.client.read(mut buf[..4])!

    // eprintln(buf[..4].map(it.hex()).join(' '))

    if buf[0] != 0x05 || buf[2] != 0x00 {
        return error("Protocol version mismatch")
    }

    mut address := ""

    cmd := match buf[1] {
        0x01 {
            RequestType.connect
        } 0x02 {
            RequestType.bind
        } 0x03 {
            RequestType.udp_associate
        } else {
            c.client.write([u8(0x05), 0x07, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])!
            return error("Command not supported")
        }
    }

    atype := match buf[3] {
        0x01 {
            AddressType.ipv4
        } 0x3 {
            AddressType.domain
        } 0x04 {
            AddressType.ipv6
        } else {
            c.client.write([u8(0x05), 0x08, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])!
            return error("Address type not supported")
        }
    }

    match atype {
        .ipv4 {
            c.client.read(mut buf[..4])!
            mut ip4 := [4]u8{}
            for i in 0 .. ip4.len {
                ip4[i] = buf[i]
            }
            address = net.new_ip(0, ip4).str()
        } .domain {
            c.client.read(mut buf[..1])!
            alen := int(buf[0])
            c.client.read(mut buf[..alen])!
            address = buf[..alen].bytestr()
        } else /* .ipv6 */ {
            c.client.read(mut buf[..16])!
            mut ip6 := [16]u8{}
            for i in 0 .. ip6.len {
                ip6[i] = buf[i]
            }
            address = net.new_ip6(0, ip6).str()
        }
    }

    c.client.read(mut buf[..2])!
    // reads packets in network byte order (big endian), but ints are little endian
    port := *(&u16(buf[..2].reverse().data))

    address = address.all_before_last(":0").trim("[]")

    return SocksRequest {
        ver:     buf[0]
        cmd:     cmd
        rsv:     0x00
        atyp:    atype
        addr:    address
        port:    port
    }
}

pub fn (mut c SocksClient) handle() {
    // eprintln("Accepted connection from " + (c.client.peer_ip() or { 'unknown' }))
    c.auth.authenticate(mut c.client) or {
        // eprintln("Authentication error: $err")
        c.client.close() or {}
        return
    }
    // eprintln("Authenticated successfully")
    for {
        req := c.read_request() or {
            // eprintln("Failed to read request: $err")
            break
        }

        req.do(mut c.client) or {
            // eprintln("Failed to perform request: $err")
            break
        }
    }
    c.client.close() or {}
}

pub fn (mut c SocksClient) close() {
    c.client.write([u8(0x05), 0x00]) or {}
    c.client.close() or {}
}

pub fn (mut s SocksServer) init()! {
    s.listener = net.listen_tcp(.ip6, '$s.lhost:$s.lport')!
}

pub fn (mut s SocksServer) listen() {
    for {
        mut client := s.listener.accept() or {
            if err.code() == net.err_timed_out_code { continue }
            // eprintln('Accept() failed: $err')
            continue
        }
        if os.fork() == 0 {
            mut sc := SocksClient {
                auth: s.auth
                client: client
            }
            sc.handle()
            exit(0)
        }
    }
}
