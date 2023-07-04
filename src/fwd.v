module fwd

import io
import net
import socks5

const (
	forwarder_agent = 0x00
	controller_agent = 0xff
)

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

pub struct FwdClient {
pub:
	raddr string
mut:
	client &net.TcpConn = voidptr(0)
}

pub fn (mut c FwdClient) init()! {
	eprintln("[+] Connecting to $c.raddr")
	c.client = net.dial_tcp(c.raddr)!
	eprintln("[+] Forwarding traffic...")
}

fn connect_forward(raddr string)! {
	mut socks := socks5.SocksClient {
		auth: socks5.SocksAuth {
			atype: .no_auth_required
		}
		client: net.dial_tcp(raddr)!
	}
	eprintln("[+] New forwarding connection from $raddr")
	socks.handle()
}

pub fn (mut c FwdClient) start()! {
	mut b := u8(0)
	defer { c.client.close() or {} }
	for {
		c.client.read_ptr(&b, 1)!
		if b == 0xff { go connect_forward(c.raddr) }
	}
}

fn port_forward(mut client &net.TcpConn, addr string) {
	defer { client.close() or {} }
	mut remote := net.dial_tcp(addr) or { return }
	defer { remote.close() or {} }
	go io.cp(mut client, mut remote)
	io.cp(mut remote, mut client) or { }
}

fn (mut s FwdServer) remote_listen() {
	for {
		mut client := s.control.accept() or {
			eprintln("Failed to accept client: $err")
			continue
		}

		s.queue <- client
	}
}

pub fn (mut s FwdServer) init()! {
	s.server = net.listen_tcp(.ip6, s.laddr)!
	if s.remote {
		s.control = net.listen_tcp(.ip6, s.raddr)!
		go s.remote_listen()
	}
}

fn remote_forward(mut client &net.TcpConn, queue chan &net.TcpConn) {
	mut target := <-queue
	go io.cp(mut target, mut client)
	io.cp(mut client, mut target) or {
		eprintln("Copy Stream error: $err")
	}
}

pub fn (mut s FwdServer) listen() {
	if s.remote {
		eprintln("[+] Waiting for remote agent to connect on $s.raddr")
		s.client = <-s.queue
	}
	eprintln("[+] Listening on $s.laddr")
	for {
		mut c := s.server.accept() or {
			// eprintln("Error while accepting connection: $err")
			continue
		}
		if s.remote {
			s.client.write([u8(0xff)]) or {
				c.close() or {}
				eprintln("Exiting due to error: $err")
				break
			}
			go remote_forward(mut c, s.queue)
		} else {
			go port_forward(mut c, s.raddr)
		}
	}
}
