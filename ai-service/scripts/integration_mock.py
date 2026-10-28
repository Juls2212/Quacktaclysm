"""Integration test: real service in MOCK mode + Godot headless (round trip and service-down fallback).

Usage (from the repository root):
    python ai-service/scripts/integration_mock.py --godot <path-to-godot-console-executable>
or set the GODOT_BIN environment variable. Creates/uses ai-service/.venv and installs the
requirements INSIDE it only. The service listens on 127.0.0.1:TEST_PORT and is always stopped.
Never uses a real key: the service is started with AI_SERVICE_MODE=mock and no OpenAI variables.
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

SERVICE_DIR = Path(__file__).resolve().parent.parent
GAME_DIR = SERVICE_DIR.parent / "game"
VENV_DIR = SERVICE_DIR / ".venv"
TEST_PORT = 8765
DOWN_PORT = 8766  # nothing listens here
SCENE = "res://frontend/scenes/test/ai_phase10_integration_test.tscn"


def venv_python() -> Path:
    return VENV_DIR / ("Scripts/python.exe" if os.name == "nt" else "bin/python")


def ensure_venv() -> Path:
    if not venv_python().exists():
        subprocess.run([sys.executable, "-m", "venv", str(VENV_DIR)], check=True)
    subprocess.run([str(venv_python()), "-m", "pip", "install", "-q", "-r", str(SERVICE_DIR / "requirements.txt")], check=True)
    return venv_python()


def run_godot(godot: str, url: str, expect: str) -> bool:
    env = {**os.environ, "QUACKTACLYSM_AI_URL": url, "QUACKTACLYSM_IT_EXPECT": expect}
    result = subprocess.run([godot, "--headless", "--path", str(GAME_DIR), SCENE], env=env,
                            capture_output=True, text=True, timeout=180)
    print(f"--- godot ({expect}) exit={result.returncode}")
    for line in result.stdout.splitlines():
        if line.startswith(("PASS", "FAIL", "RESULT", "base url")):
            print(line)
    return result.returncode == 0 and "RESULT: PASS" in result.stdout


def wait_for_health(port: int, seconds: float = 20.0) -> bool:
    deadline = time.time() + seconds
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(f"http://127.0.0.1:{port}/health", timeout=1) as response:
                if response.status == 200:
                    return True
        except OSError:
            time.sleep(0.3)
    return False


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", ""))
    args = parser.parse_args()
    if not args.godot:
        print("Pass --godot <console executable> or set GODOT_BIN")
        return 2
    python = ensure_venv()
    env = {k: v for k, v in os.environ.items() if not k.startswith("OPENAI_")}
    env.update({"AI_SERVICE_MODE": "mock", "AI_SERVICE_HOST": "127.0.0.1", "AI_SERVICE_PORT": str(TEST_PORT)})
    service = subprocess.Popen([str(python), "run_dev.py"], cwd=SERVICE_DIR, env=env,
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    ok = False
    try:
        if not wait_for_health(TEST_PORT):
            print("service did not become healthy")
            return 1
        ok_round_trip = run_godot(args.godot, f"http://127.0.0.1:{TEST_PORT}", "ok")
        ok_down = run_godot(args.godot, f"http://127.0.0.1:{DOWN_PORT}", "down")
        ok = ok_round_trip and ok_down
    finally:
        service.terminate()
        try:
            service.wait(timeout=10)
        except subprocess.TimeoutExpired:
            service.kill()
    print("INTEGRATION:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
