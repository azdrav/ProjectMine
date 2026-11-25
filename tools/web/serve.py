#!/usr/bin/env python3
"""Serve a local ProjectMine trial with correct WebAssembly MIME types (stdlib only)."""
import argparse
import functools
import ssl
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import threading
import webbrowser


class Handler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map,
                      ".wasm": "application/wasm", ".pck": "application/octet-stream",
                      ".js": "text/javascript"}

    def end_headers(self):
        # Local trial: do not serve a stale mix of builds after rebuilding/reloading.
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def main():
    folder = Path(__file__).resolve().parent
    if not (folder / "index.html").exists():
        folder = folder.parents[1] / "build" / "web"
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, default=folder)
    parser.add_argument("--port", type=int, default=8060)
    parser.add_argument("--host", default="127.0.0.1",
                        help="Bind address; use a LAN IP or 0.0.0.0 for network access")
    parser.add_argument("--no-open", action="store_true")
    parser.add_argument("--https", action="store_true", help="Use the local LAN test certificate")
    parser.add_argument("--cert", type=Path, help="Custom PEM server certificate")
    parser.add_argument("--key", type=Path, help="Custom PEM private key")
    args = parser.parse_args()
    if not (args.directory / "index.html").is_file():
        parser.error("No index.html found. Build first with python3 tools/web/build.py")
    handler = functools.partial(Handler, directory=str(args.directory.resolve()))
    if bool(args.cert) != bool(args.key):
        parser.error("--cert and --key must be supplied together")
    use_tls = args.https or args.cert is not None
    context = None
    if use_tls:
        certificates = Path.home() / ".local" / "share" / "projectmine-web" / "certs"
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.minimum_version = ssl.TLSVersion.TLSv1_2
        try:
            context.load_cert_chain(args.cert or certificates / "server.crt",
                                    args.key or certificates / "server.key")
        except (OSError, ssl.SSLError) as error:
            parser.error(f"Cannot load HTTPS certificate: {error}. "
                         "Run python3 tools/web/create_lan_certificate.py --ip <LAN-IP> first")
    try:
        server = ThreadingHTTPServer((args.host, args.port), handler)
    except OSError as error:
        parser.error(f"Cannot start server: {error}. Try --port 8061")
    server.daemon_threads = True
    if context is not None:
        server.socket = context.wrap_socket(server.socket, server_side=True)
    local_host = "localhost" if args.host in ("127.0.0.1", "0.0.0.0") else args.host
    scheme = "https" if use_tls else "http"
    address = f"{scheme}://{local_host}:{server.server_port}/"
    print(f"ProjectMine web trial: {address}\nKeep this window open. Ctrl+C stops the server.", flush=True)
    if use_tls:
        print("HTTPS active. Client browsers must trust the ProjectMine LAN Test CA "
              "before playing; no trust stores are modified by this server.", flush=True)
    elif args.host not in ("127.0.0.1", "localhost"):
        print(f"Network binding: {args.host}:{server.server_port}. "
              "Remote plain HTTP is not a secure context; this Godot build requires HTTPS "
              "or localhost (e.g. an SSH tunnel) to run.", flush=True)
    if not args.no_open:
        threading.Timer(0.3, webbrowser.open, args=(address,)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
