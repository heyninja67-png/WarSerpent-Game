#!/usr/bin/env python3
"""Two independent Godot processes exchange actual ENet UDP packets on loopback.
Local transport validation does not claim NAT, public server or Android testing.
"""
import os
from pathlib import Path
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
LOGS = Path(tempfile.mkdtemp(prefix="warserpent-network-", dir="/tmp"))
ENV = dict(os.environ, XDG_CONFIG_HOME="/workspace/.config", XDG_DATA_HOME=str(LOGS / "data"), XDG_CACHE_HOME="/workspace/.cache")
COMMAND = [os.environ.get("GODOT", "godot"), "--headless", "--path", str(ROOT), "--script", "tests/test_network_peer.gd", "--"]

def pair(client_mode):
    with (LOGS / f"{client_mode}-host.log").open("w") as server_log, (LOGS / f"{client_mode}.log").open("w") as guest_log:
        host = subprocess.Popen(COMMAND + ["host"], env=ENV, stdout=server_log, stderr=subprocess.STDOUT)
        try:
            time.sleep(0.5)
            client = subprocess.run(COMMAND + [client_mode], env=ENV, stdout=guest_log, stderr=subprocess.STDOUT, timeout=12)
            server_code = host.wait(timeout=10)
            if client.returncode != 0 or server_code != 0:
                raise RuntimeError(f"{client_mode}: host={server_code}, client={client.returncode}")
        finally:
            if host.poll() is None:
                host.terminate()
                host.wait(timeout=5)

def main():
    try:
        pair("client")
        pair("disconnect")
        result = subprocess.run(COMMAND + ["unreachable"], env=ENV, text=True, capture_output=True, timeout=5)
        (LOGS / "unreachable.log").write_text(result.stdout + result.stderr)
        if result.returncode != 0:
            raise RuntimeError("Unreachable-room test failed")
        for log in sorted(LOGS.glob("*.log")):
            text = log.read_text()
            print(f"--- {log.name} ---\n{text}")
            if any(marker in text for marker in ["SCRIPT ERROR", "FAIL:", "ObjectDB instances leaked", "above the MTU"]):
                raise RuntimeError(f"Runtime error: {log}")
        print(f"MULTIPLAYER PASS: real two-process UDP movement, food, cooldowns, host disconnect and timeout; logs={LOGS}")
    except Exception:
        for log in sorted(LOGS.glob("*.log")):
            print(f"--- {log.name} ---\n{log.read_text()}")
        raise

if __name__ == "__main__":
    main()
