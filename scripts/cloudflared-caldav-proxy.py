#!/usr/bin/env python3
"""Restricted reverse proxy for exposing only CalDAV through a tunnel.

The admin UI is never forwarded. Run caldav-free locally (HTTPS or HTTP) and
point this proxy at it; then expose the proxy with a tunnel such as
`cloudflared tunnel --url http://127.0.0.1:5233`.

Usage:
    scripts/cloudflared-caldav-proxy.py [--listen 127.0.0.1:5233]
        [--upstream 127.0.0.1:5232] [--insecure]

The proxy intentionally rejects POST, so the admin login/forms and future
scheduling endpoints cannot be reached through the tunnel.
"""

from __future__ import annotations

import argparse
import http.client
import ssl
import sys
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

DAV_METHODS = {
    "OPTIONS",
    "PROPFIND",
    "PROPPATCH",
    "REPORT",
    "GET",
    "HEAD",
    "PUT",
    "DELETE",
    "MKCALENDAR",
    "MKCOL",
}

ALLOWED_PATHS = ("/principals", "/calendars", "/.well-known/caldav", "/healthz")
BLOCKED_PREFIXES = ("/admin", "/login", "/logout", "/assets", "/favicon.ico")
HOP_BY_HOP = {
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailers",
    "transfer-encoding",
    "upgrade",
}
MAX_BODY = 16 * 1024 * 1024

UPSTREAM_HOST = "127.0.0.1"
UPSTREAM_PORT = 5232
UPSTREAM_TLS = True
INSECURE = True


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "caldav-tunnel-proxy"
    sys_version = ""

    def log_message(self, fmt: str, *args) -> None:
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    def _deny(self, status: int, message: str) -> None:
        body = (message + "\n").encode()
        self.send_response(status)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def _read_body(self) -> bytes | None:
        if self.headers.get("Transfer-Encoding", "").lower() == "chunked":
            chunks = []
            total = 0
            while True:
                line = self.rfile.readline(1024).strip()
                if not line:
                    break
                try:
                    size = int(line.split(b";", 1)[0], 16)
                except ValueError:
                    raise ValueError("invalid chunk size")
                if size == 0:
                    self.rfile.readline(1024)
                    break
                total += size
                if total > MAX_BODY:
                    raise ValueError("request body too large")
                chunks.append(self.rfile.read(size))
                self.rfile.read(2)
            return b"".join(chunks)
        length = int(self.headers.get("Content-Length", "0") or "0")
        if length <= 0:
            return None
        if length > MAX_BODY:
            raise ValueError("request body too large")
        return self.rfile.read(length)

    def _proxy(self) -> None:
        method = self.command
        if method not in DAV_METHODS:
            self._deny(405, "method not allowed")
            return

        parsed = urllib.parse.urlsplit(self.path)
        path = urllib.parse.unquote(parsed.path or "/")
        if any(path == p or path.startswith(p + "/") for p in BLOCKED_PREFIXES):
            self._deny(404, "not found")
            return
        if path == "*":
            if method != "OPTIONS":
                self._deny(405, "method not allowed")
                return
        elif path == "/":
            if method not in {"OPTIONS", "PROPFIND"}:
                self._deny(405, "method not allowed")
                return
        elif not any(path == p or path.startswith(p + "/") for p in ALLOWED_PATHS):
            self._deny(404, "not found")
            return

        try:
            body = self._read_body()
        except ValueError as exc:
            self._deny(400, str(exc))
            return

        headers = {
            key: value
            for key, value in self.headers.items()
            if key.lower() not in HOP_BY_HOP and key.lower() != "host"
        }
        headers["Host"] = f"{UPSTREAM_HOST}:{UPSTREAM_PORT}"
        headers["X-Forwarded-Proto"] = "https"

        context = None
        if UPSTREAM_TLS:
            context = ssl._create_unverified_context() if INSECURE else ssl.create_default_context()
            conn = http.client.HTTPSConnection(UPSTREAM_HOST, UPSTREAM_PORT, context=context, timeout=120)
        else:
            conn = http.client.HTTPConnection(UPSTREAM_HOST, UPSTREAM_PORT, timeout=120)

        try:
            forward_path = "/" if path == "*" else self.path
            conn.request(method, forward_path, body=body, headers=headers)
            resp = conn.getresponse()
            data = resp.read()
        except Exception as exc:  # noqa: BLE001 - report tunnel errors to the client
            self.log_message("upstream error: %s", exc)
            self._deny(502, "upstream unavailable")
            return
        finally:
            conn.close()

        self.send_response(resp.status)
        for key, value in resp.getheaders():
            lower = key.lower()
            if lower in HOP_BY_HOP or lower == "content-length":
                continue
            self.send_header(key, value)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        if method != "HEAD" and resp.status not in (204, 304):
            self.wfile.write(data)

    do_GET = _proxy
    do_HEAD = _proxy
    do_OPTIONS = _proxy
    do_PROPFIND = _proxy
    do_PROPPATCH = _proxy
    do_REPORT = _proxy
    do_PUT = _proxy
    do_DELETE = _proxy
    do_MKCALENDAR = _proxy
    do_MKCOL = _proxy


def main() -> None:
    global UPSTREAM_HOST, UPSTREAM_PORT, UPSTREAM_TLS, INSECURE
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--listen", default="127.0.0.1:5233")
    parser.add_argument("--upstream", default="127.0.0.1:5232")
    parser.add_argument("--insecure", action="store_true", default=True, help="skip upstream TLS verification")
    parser.add_argument("--verify-upstream", action="store_true", help="verify upstream TLS certificate")
    args = parser.parse_args()

    listen_host, listen_port = args.listen.rsplit(":", 1)
    UPSTREAM_HOST, upstream_port = args.upstream.rsplit(":", 1)
    UPSTREAM_PORT = int(upstream_port)
    INSECURE = not args.verify_upstream

    server = ThreadingHTTPServer((listen_host, int(listen_port)), Handler)
    print(f"CalDAV-only proxy listening on http://{args.listen} -> "
          f"{'https' if UPSTREAM_TLS else 'http'}://{args.upstream}", file=sys.stderr)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
