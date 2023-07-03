module main

import os
import cli
import fwd
import socks5

fn standalone(cmd cli.Command)! {
	mut users := map[string] string
	for cred in cmd.flags.get_strings('creds')! {
		users[cred.all_before(':')] = cred.all_after_first(':')
	}
	mut s := socks5.SocksServer {
		lport: cmd.flags.get_int('port')!
		lhost: cmd.flags.get_string('host')!
		auth: socks5.SocksAuth {
			atype: if cmd.flags.get_bool('auth')! { .username_password } else { .no_auth_required }
			users: users
		}
	}
	s.init()!
	s.listen()
}

fn server(cmd cli.Command)! {
	return error("Not implemented yet")
}

fn forward(cmd cli.Command)! {
	to := cmd.flags.get_string('to')!
	from := cmd.flags.get_string('from')!
	remote := cmd.flags.get_bool('remote')!

	if remote {
		return error("Not implemented yet")
	}

	if !from.contains(":") {
		return error("Wrong value for parameter `from`")
	}

	if !to.contains(":") {
		return error("Wrong value for parameter `to`")
	}

	mut server := fwd.FwdServer {
		laddr: from.replace("*", "")
		raddr: to
	}

	server.init()!
	server.listen()
}

fn main() {
	mut app := cli.Command {
		name: 'vfwd'
		version: '0.0.1'
		posix_mode: true
		description: 'A V tool for tunneling and port fowarding'
		commands: [
			cli.Command {
				name: 'standalone'
				execute: standalone
				description: "Run as a standalone SOCKS5 proxy server"
				flags: [
					cli.Flag {
						flag: .int
						name: 'port'
						abbrev: 'p'
						description: 'Port to listen on (default: 1080)'
						default_value: ['1080']
					},
					cli.Flag {
						flag: .string
						name: 'host'
						abbrev: 'l'
						description: 'Listen host (ipv6 format)'
						default_value: ['::']
					},
					cli.Flag {
						flag: .bool
						name: 'auth'
						abbrev: 'a'
						description: 'Require authentication'
					},
					cli.Flag {
						flag: .string_array
						name: 'creds'
						abbrev: 'c'
						description: 'A username:password combination to allow'
					},
				]
			},
			cli.Command {
				name: 'forward'
				description: 'Run forward mode'
				execute: forward
				flags: [
					cli.Flag {
						flag: .string
						name: 'from'
						abbrev: 'f'
						required: true
						description: 'Address to listen/forward from (ex: ::8080)'
						// required: true
					},
					cli.Flag {
						flag: .string
						name: 'to'
						abbrev: 't'
						description: 'Address to send traffic to (ex: 192.168.0.1:8080)'
						// required: true
					},
					cli.Flag {
						flag: .bool
						name: 'remote'
						abbrev: 'r'
						description: 'Forward from remote host'
					},
				]
			},
		]
	}
	app.setup()
	app.parse(os.args)
}
