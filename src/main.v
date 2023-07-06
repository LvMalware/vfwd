module main

import os
import cli
import fwd
import socks5

fn standalone(cmd cli.Command) ! {
	mut users := map[string]string{}
	for cred in cmd.flags.get_strings('creds')! {
		users[cred.all_before(':')] = cred.all_after_first(':')
	}
	mut s := socks5.SocksServer{
		laddr: cmd.flags.get_string('listen')!.replace('*', '')
		auth: socks5.SocksAuth{
			atype: if cmd.flags.get_bool('auth')! { .username_password } else { .no_auth_required }
			users: users
		}
	}
	s.init()!
	eprintln('[+] Listening on ${s.laddr}')
	s.listen()
}

fn server(cmd cli.Command) ! {
	from := cmd.flags.get_string('socks-listen')!
	to := cmd.flags.get_string('control-listen')!
	if !from.contains(':') {
		return error('Wrong value for `socks-listen` flag')
	}
	if !to.contains(':') {
		return error('Wrong value for `control-listen` flag')
	}
	mut s := fwd.FwdServer{
		laddr: from.replace('*', '')
		raddr: to.replace('*', '')
		remote: true
	}
	s.init()!
	s.listen()
}

fn forward(cmd cli.Command) ! {
	to := cmd.flags.get_string('to')!
	from := cmd.flags.get_string('from')!
	remote := cmd.flags.get_bool('remote')!

	if remote {
		mut f := fwd.FwdClient{
			raddr: from
		}
		f.init()!
		f.start()!
	}

	if !from.contains(':') {
		return error('Wrong value for parameter `from`')
	}

	if !to.contains(':') {
		return error('Wrong value for parameter `to`')
	}

	mut server := fwd.FwdServer{
		laddr: from.replace('*', '')
		raddr: to
	}

	server.init()!
	eprintln('[+] Forwarding all traffic from ${from} to ${to}')
	server.listen()
}

fn main() {
	mut app := cli.Command{
		name: 'vfwd'
		version: '0.0.1'
		posix_mode: true
		description: 'A V tool for tunneling and port fowarding'
		commands: [
			cli.Command{
				name: 'standalone'
				execute: standalone
				description: 'Run as a standalone SOCKS5 proxy server'
				flags: [
					cli.Flag{
						flag: .string
						name: 'listen'
						abbrev: 'l'
						description: 'Address to listen on (ex: :1080)'
						default_value: [':1080']
					},
					cli.Flag{
						flag: .bool
						name: 'auth'
						abbrev: 'a'
						description: 'Require authentication'
					},
					cli.Flag{
						flag: .string_array
						name: 'creds'
						abbrev: 'c'
						description: 'A username:password combination to allow'
					},
				]
			},
			cli.Command{
				name: 'forward'
				description: 'Run forward mode'
				execute: forward
				flags: [
					cli.Flag{
						flag: .string
						name: 'from'
						abbrev: 'f'
						required: true
						description: 'Address to listen/forward from (ex: ::8080)'
						// required: true
					},
					cli.Flag{
						flag: .string
						name: 'to'
						abbrev: 't'
						description: 'Address to send traffic to (ex: 192.168.0.1:8080)'
						// required: true
					},
					cli.Flag{
						flag: .bool
						name: 'remote'
						abbrev: 'r'
						description: 'Forward from remote host'
					},
				]
			},
			cli.Command{
				name: 'server'
				description: 'Run as a server for remote forward'
				execute: server
				flags: [
					cli.Flag{
						flag: .string
						name: 'socks-listen'
						abbrev: 'l'
						description: 'Address to listen on as a socks5 proxy (ex: :1080)'
						default_value: [':1080']
					},
					cli.Flag{
						flag: .string
						name: 'control-listen'
						abbrev: 'c'
						description: 'Address to listen on for remote agents (ex: :1337)'
						default_value: [':1337']
					},
				]
			},
		]
	}
	app.setup()
	app.parse(os.args)
}
