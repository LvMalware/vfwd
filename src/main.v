module main

import os
import cli
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
						found: true
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
				name: 'server'
				description: 'Run in server mode'
				execute: server
				flags: [
				]
			},
			cli.Command {
				name: 'client'
				description: 'Run in client mode'
				execute: server
				flags: [
				]
			},
		]
	}
	app.setup()
	app.parse(os.args)
}
