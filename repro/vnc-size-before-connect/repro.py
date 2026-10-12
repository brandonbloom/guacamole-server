#!/usr/bin/env python3
"""Reproduce guacd dropping a VNC connection when the client sends "size"
while guacd is still waiting for VNC credentials.

Runs two things:
  * a stub VNC server that offers only VNC password authentication, sends its
    challenge, and then waits, so guacd's VNC connection stays in the
    credentials stage indefinitely;
  * a client that speaks the Guacamole protocol directly to guacd (no web
    application), connects without a password so guacd sends "required",
    then sends a "size" instruction.

Usage: repro.py GUACD_HOST [--no-size] [--disable-display-resize]
                [--stub-host ADDRESS] [--stub-port PORT]
"""

import argparse
import os
import socket
import threading
import time

def stub_vnc_server(port: int, ready: threading.Event) -> None:
    listener = socket.create_server(("0.0.0.0", port))
    ready.set()
    while True:
        connection, peer = listener.accept()
        threading.Thread(target=hold, args=(connection, peer), daemon=True).start()


def hold(connection: socket.socket, peer) -> None:
    with connection:
        connection.sendall(b"RFB 003.008\n")
        connection.recv(12)
        connection.sendall(bytes([1, 2]))       # one security type: VNC authentication
        connection.recv(1)
        connection.sendall(os.urandom(16))      # challenge; the reply needs a password
        print(f"stub VNC server: {peer[0]} is in the credentials stage", flush=True)
        while connection.recv(4096):
            pass


def encode(*elements: str) -> bytes:
    return (",".join(f"{len(e)}.{e}" for e in elements) + ";").encode()


class Reader:
    def __init__(self, sock: socket.socket) -> None:
        self.sock, self.buffer = sock, b""

    def instruction(self):
        """The next instruction as a list of elements, or None at EOF."""
        while b";" not in self.buffer:
            chunk = self.sock.recv(65536)
            if not chunk:
                return None
            self.buffer += chunk
        text = self.buffer.decode()
        elements, i = [], 0
        while True:
            dot = text.index(".", i)
            length = int(text[i:dot])
            elements.append(text[dot + 1:dot + 1 + length])
            i = dot + 1 + length
            if text[i] == ";":
                break
            i += 1
        self.buffer = text[i + 1:].encode()
        return elements


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("guacd")
    parser.add_argument("--no-size", action="store_true", help="never send size (control case)")
    parser.add_argument("--disable-display-resize", action="store_true",
                        help="set the connection's disable-display-resize parameter (workaround)")
    parser.add_argument("--stub-host", help="address guacd reaches the stub at (default: this host's)")
    parser.add_argument("--stub-port", type=int, default=5900)
    args = parser.parse_args()

    ready = threading.Event()
    threading.Thread(target=stub_vnc_server, args=(args.stub_port, ready), daemon=True).start()
    ready.wait()

    sock = socket.create_connection((args.guacd, 4822), timeout=10)
    reader = Reader(sock)
    sock.sendall(encode("select", "vnc"))
    names = reader.instruction()
    if not names or names[0] != "args":
        print(f"✗ guacd did not offer connection arguments: {names}", flush=True)
        return 2
    values = {"hostname": args.stub_host or socket.gethostbyname(socket.gethostname()),
              "port": str(args.stub_port)}
    if args.disable_display_resize:
        values["disable-display-resize"] = "true"
    sock.sendall(encode("size", "1024", "768", "96") + encode("audio") + encode("video")
                 + encode("image", "image/png") + encode("timezone", "UTC")
                 + encode("connect", names[1], *[values.get(name, "") for name in names[2:]]))

    start = time.time()
    sent_size = False
    sock.settimeout(1)
    while time.time() - start < 10:
        try:
            instruction = reader.instruction()
        except socket.timeout:
            instruction = []
        if instruction is None:
            print(f"✗ guacd closed the connection {time.time() - start:.1f}s after connecting"
                  + (" (after the size instruction)" if sent_size else ""), flush=True)
            return 1
        if instruction and instruction[0] in ("ready", "required", "error"):
            print(f"guacd: {instruction}", flush=True)
        if instruction and instruction[0] == "required" and not args.no_size:
            time.sleep(1)
            print("client: sending size 390x500 while guacd waits for the password", flush=True)
            sock.sendall(encode("size", "390", "500"))
            sent_size = True
        sock.sendall(encode("nop"))
    print("✓ connection still open after 10s", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
