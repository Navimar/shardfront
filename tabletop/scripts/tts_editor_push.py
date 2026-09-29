#!/usr/bin/env python3
"""Push a Global Lua script to a running Tabletop Simulator Save & Play API."""

from __future__ import annotations

import argparse
import json
import socket
import time
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("script", type=Path, nargs="?")
    action.add_argument("--execute", metavar="LUA")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=39999)
    parser.add_argument("--listen", action="store_true")
    parser.add_argument("--response-port", type=int, default=39998)
    parser.add_argument("--response-timeout", type=float, default=15.0)
    args = parser.parse_args()

    listener = None
    if args.listen:
        listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        listener.bind((args.host, args.response_port))
        listener.listen()
        listener.settimeout(0.5)

    if args.execute is not None:
        message = {"messageID": 3, "guid": "-1", "script": args.execute}
        summary = f"Executed Global Lua: {args.execute}"
    else:
        script = args.script.read_text(encoding="utf-8")
        message = {
            "messageID": 1,
            "scriptStates": [
                {
                    "name": "Global",
                    "guid": "-1",
                    "script": script,
                    "ui": "",
                }
            ],
        }
        summary = f"Sent {len(script)} characters to Tabletop Simulator"
    payload = json.dumps(message, ensure_ascii=False, separators=(",", ":")).encode(
        "utf-8"
    )

    with socket.create_connection((args.host, args.port), timeout=5) as connection:
        connection.sendall(payload)
        connection.shutdown(socket.SHUT_WR)

    print(f"{summary} at {args.host}:{args.port}")

    if listener is not None:
        deadline = time.monotonic() + args.response_timeout
        while time.monotonic() < deadline:
            try:
                client, _ = listener.accept()
            except TimeoutError:
                continue
            with client:
                chunks = []
                while True:
                    chunk = client.recv(65536)
                    if not chunk:
                        break
                    chunks.append(chunk)
            raw = b"".join(chunks).decode("utf-8")
            response = {}
            try:
                response = json.loads(raw)
                print(json.dumps(response, ensure_ascii=False, indent=2))
            except json.JSONDecodeError:
                print(raw)
            if response.get("messageID") in {3, 5}:
                break
        listener.close()


if __name__ == "__main__":
    main()
