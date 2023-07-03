module fwd

import os
import net
import socks5

type FnConnectionCallback = fn (mut &net.TcpConn, string)

pub struct FwdServer {
pub:
	laddr string
	raddr string
	queue chan &net.TcpConn
	remote bool
mut:
	client &net.TcpConn = voidptr(0)
	server &net.TcpListener = voidptr(0)
	control &net.TcpListener = voidptr(0)
}

fn port_forward(mut client &net.TcpConn, addr string) {
	defer { client.close() or {} }
	mut remote := net.dial_tcp(addr) or { return }
	defer { remote.close() or {} }
	go socks5.copy_stream(mut client, mut remote)
	socks5.copy_stream(mut remote, mut client) or {}
}

pub fn (mut s FwdServer) init()! {
	s.server = net.listen_tcp(.ip6, "$s.laddr")!
	if s.remote {
		eprintln("[+] Waiting for remote agent to connect on $s.raddr")
		mut listen := net.listen_tcp(.ip6, "$s.raddr")!
		defer { listen.close() or {} }
		s.client = listen.accept()!
	}
	eprintln("[+] Listening on $s.laddr")
}

fn remote_forward(mut client &net.TcpConn, queue chan &net.TcpConn) {
}

pub fn (mut s FwdServer) listen() {
	for {
		mut c := s.server.accept() or {
			// eprintln("Error while accepting connection: $err")
			continue
		}
		if os.fork() == 0 {
			if s.remote {
			} else {
				$if debug {
					if addr := c.peer_ip() {
						eprintln("[+] Forwarding connection from $addr to $s.raddr")
					}
				}
				port_forward(mut c, s.raddr)
				exit(0)
			}
		}
	}
}
