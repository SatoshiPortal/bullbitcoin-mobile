"""Read-only reachability check of the hosted regtest stack.

Usage: python3 tools/regtest/check_hosted.py tools/regtest/hosted.json

Every check only reads: Esplora and Electrum tips, the Boltz version and its
websocket handshake, the Ark server and, when TOR_SOCKS=host:port names a Tor
SOCKS proxy, the RecoverBull key server info. Exits non-zero on any failure.
"""

import base64
import json
import os
import socket
import ssl
import sys
import urllib.parse
import urllib.request

TIMEOUT = 20


def get(url):
    request = urllib.request.Request(url, headers={"User-Agent": "regtest-check"})
    with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
        return response.status, response.read()


def tip(url):
    status, body = get(url.rstrip("/") + "/blocks/tip/height")
    height = int(body)
    assert status == 200 and height > 0
    return height


def electrum_tip(url):
    endpoint = urllib.parse.urlsplit(url)
    assert endpoint.scheme == "ssl", url
    context = ssl.create_default_context()
    with socket.create_connection((endpoint.hostname, endpoint.port), TIMEOUT) as raw:
        with context.wrap_socket(raw, server_hostname=endpoint.hostname) as tls:
            request = {"id": 1, "method": "blockchain.headers.subscribe", "params": []}
            tls.sendall(json.dumps(request).encode() + b"\n")
            reply = json.loads(tls.makefile("rb").readline())
    return reply["result"]["height"]


def boltz(url):
    status, body = get(url.rstrip("/") + "/version")
    assert status == 200
    return json.loads(body)["version"]


def websocket(url):
    endpoint = urllib.parse.urlsplit(url)
    assert endpoint.scheme == "wss", url
    context = ssl.create_default_context()
    key = base64.b64encode(os.urandom(16)).decode()
    request = (
        f"GET {endpoint.path or '/'} HTTP/1.1\r\nHost: {endpoint.hostname}\r\n"
        "Upgrade: websocket\r\nConnection: Upgrade\r\n"
        f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n"
    )
    with socket.create_connection((endpoint.hostname, endpoint.port or 443), TIMEOUT) as raw:
        with context.wrap_socket(raw, server_hostname=endpoint.hostname) as tls:
            tls.sendall(request.encode())
            status = tls.makefile("rb").readline().decode().strip()
    assert " 101 " in status + " ", status
    return status


def ark(url):
    status, _ = get(url)
    assert status < 400
    return status


def recoverbull(url, proxy):
    host, port = proxy.rsplit(":", 1)
    target = urllib.parse.urlsplit(url)
    with socket.create_connection((host, int(port)), TIMEOUT * 3) as sock:
        sock.sendall(b"\x05\x01\x00")
        assert sock.recv(2) == b"\x05\x00", "SOCKS5 handshake refused"
        name = target.hostname.encode()
        sock.sendall(
            b"\x05\x01\x00\x03"
            + bytes([len(name)])
            + name
            + (target.port or 80).to_bytes(2, "big")
        )
        reply = sock.recv(10)
        assert reply[1] == 0, f"SOCKS5 connect failed: {reply[1]}"
        sock.sendall(
            f"GET /info HTTP/1.1\r\nHost: {target.hostname}\r\nConnection: close\r\n\r\n".encode()
        )
        status = sock.makefile("rb").readline().decode().strip()
    assert " 200 " in status + " ", status
    return status


def main():
    with open(sys.argv[1], encoding="utf-8") as config:
        defines = json.load(config)
    checks = [
        ("Esplora Bitcoin", tip, defines["BULL_REGTEST_HOSTED_ESPLORA_BITCOIN"]),
        ("Esplora Liquid", tip, defines["BULL_REGTEST_HOSTED_ESPLORA_LIQUID"]),
        ("Electrum Bitcoin", electrum_tip, defines["BULL_REGTEST_HOSTED_ELECTRUM_BITCOIN"]),
        ("Electrum Liquid", electrum_tip, defines["BULL_REGTEST_HOSTED_ELECTRUM_LIQUID"]),
        ("Boltz API", boltz, defines["BULL_REGTEST_HOSTED_BOLTZ_API"]),
        ("Boltz websocket", websocket, defines["BULL_REGTEST_HOSTED_BOLTZ_WS"]),
        ("Ark server", ark, defines["BULL_ARK_REGTEST_URL"]),
    ]
    failed = False
    for name, check, url in checks:
        try:
            print(f"ok   {name}: {check(url)}")
        except Exception as error:  # noqa: BLE001 - report every failing service
            failed = True
            print(f"FAIL {name} ({url}): {error}")
    proxy = os.environ.get("TOR_SOCKS")
    url = defines["BULL_REGTEST_HOSTED_RECOVERBULL"]
    if proxy:
        try:
            print(f"ok   RecoverBull: {recoverbull(url, proxy)}")
        except Exception as error:  # noqa: BLE001
            failed = True
            print(f"FAIL RecoverBull ({url}): {error}")
    else:
        print("skip RecoverBull: set TOR_SOCKS=host:port to check the onion service")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
