#!/usr/bin/env python3
"""Regression runner for the Godot smoke / e2e / playthrough tests of Quacktaclysm.

Standard library only. Works on Windows, macOS and Linux. No absolute paths: the Godot executable
comes from --godot, the GODOT_BIN environment variable, or `godot` / `godot4` in PATH.

Examples:
    python tools/run_all_tests.py
    python tools/run_all_tests.py --only boss --timeout 120
    python tools/run_all_tests.py --list
    GODOT_BIN=/path/to/godot python tools/run_all_tests.py
"""
from __future__ import annotations

import argparse
import hashlib
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
GAME_DIR = REPO_ROOT / "game"
TEST_DIR = GAME_DIR / "frontend" / "scenes" / "test"
PATTERNS = ("*_smoke_test.tscn", "*_e2e_test.tscn", "*_playthrough_test.tscn", "*_soak_test.tscn", "*_leak_test.tscn")
# Needs a real AI service and an environment variable: run ai-service/scripts/integration_mock.py instead.
EXCLUDED = {"ai_phase10_integration_test.tscn"}
# Longer budgets for the long-running soak and leak scenes (seconds).
# Extra Godot arguments: fixed 60 fps removes the real-time wait of long simulations.
EXTRA_ARGS = {"bot_phase13_soak_test": ["--fixed-fps", "60"], "flow_phase13_leak_test": ["--fixed-fps", "60"]}
TIMEOUT_OVERRIDES = {"bot_phase13_soak_test": 1800, "flow_phase13_leak_test": 900}
# Accepts "RESULT: PASS (0 failure(s))" and variants such as "RESULT (before real transition): PASS (0 ...".
RESULT_RE = re.compile(r"^RESULT[^:]*:\s*(PASS|FAIL)\s*\((\d+)\s+failure")
ERROR_RE = re.compile(r"^(SCRIPT ERROR|ERROR):")


def find_godot(cli_value: str | None) -> str | None:
    candidates = [cli_value, os.environ.get("GODOT_BIN")]
    for candidate in candidates:
        if candidate:
            return candidate if Path(candidate).exists() else shutil.which(candidate)
    return shutil.which("godot") or shutil.which("godot4")


def discover(only: str | None) -> list[Path]:
    found: dict[str, Path] = {}
    for pattern in PATTERNS:
        for path in TEST_DIR.glob(pattern):
            if path.name not in EXCLUDED:
                found[path.name] = path
    tests = [found[name] for name in sorted(found)]
    if only:
        tests = [path for path in tests if only in path.stem]
    return tests


def user_data_dir() -> Path | None:
    """Godot's per-project user folder (user://), resolved from `config/name` in project.godot."""
    try:
        text = (GAME_DIR / "project.godot").read_text(encoding="utf-8")
    except OSError:
        return None
    match = re.search(r'^config/name="([^"]+)"', text, re.MULTILINE)
    if not match or re.search(r"^config/use_custom_user_dir\s*=\s*true", text, re.MULTILINE):
        return None
    name = match.group(1)
    if sys.platform == "win32":
        base = os.environ.get("APPDATA")
        return Path(base) / "Godot" / "app_userdata" / name if base else None
    if sys.platform == "darwin":
        return Path.home() / "Library" / "Application Support" / "Godot" / "app_userdata" / name
    data_home = os.environ.get("XDG_DATA_HOME") or str(Path.home() / ".local" / "share")
    return Path(data_home) / "godot" / "app_userdata" / name


def save_digest() -> str | None:
    """SHA-256 of the real save file, 'missing' if it does not exist, None if the folder is unknown."""
    folder = user_data_dir()
    if folder is None:
        return None
    save = folder / "save_game.json"
    return hashlib.sha256(save.read_bytes()).hexdigest() if save.exists() else "missing"


def run_one(godot: str, test: Path, timeout: int) -> dict:
    scene = "res://frontend/scenes/test/" + test.name
    command = [godot, "--headless", *EXTRA_ARGS.get(test.stem, []), "--path", str(GAME_DIR), scene]
    started = time.time()
    timed_out = False
    try:
        completed = subprocess.run(command, cwd=REPO_ROOT, capture_output=True, text=True, encoding="utf-8",
                                   errors="replace", timeout=timeout)
        output, code = completed.stdout + "\n" + completed.stderr, completed.returncode
    except subprocess.TimeoutExpired as error:
        timed_out = True
        raw = (error.stdout or b"")
        output = raw.decode("utf-8", "replace") if isinstance(raw, bytes) else str(raw)
        code = -1
    lines = output.splitlines()
    passes = sum(1 for line in lines if line.startswith("PASS"))
    fails = sum(1 for line in lines if line.startswith("FAIL"))
    errors = [line for line in lines if ERROR_RE.match(line)]
    warnings = sum(1 for line in lines if line.startswith("WARNING:"))
    result = None
    for line in lines:
        match = RESULT_RE.match(line)
        if match:
            result = (match.group(1), int(match.group(2)))
    ok = (not timed_out and code == 0 and result is not None and result[0] == "PASS" and result[1] == 0 and fails == 0 and not errors)
    return {"name": test.stem, "pass": passes, "fail": fails, "errors": errors, "warnings": warnings, "code": code,
            "seconds": time.time() - started, "ok": ok, "timed_out": timed_out, "result": result, "output": output}


def main() -> int:
    parser = argparse.ArgumentParser(description="Run every Godot test scene headless and summarize.")
    parser.add_argument("--godot", help="Path to the Godot executable (else GODOT_BIN, else godot/godot4 in PATH)")
    parser.add_argument("--timeout", type=int, default=300, help="Seconds per test (default 300)")
    parser.add_argument("--only", help="Run only the tests whose name contains this text")
    parser.add_argument("--list", action="store_true", help="List the discovered tests and exit")
    parser.add_argument("--verbose", action="store_true", help="Print the output of failing tests")
    args = parser.parse_args()

    tests = discover(args.only)
    if args.list:
        for test in tests:
            print(test.stem)
        return 0
    if not tests:
        print("No tests found.")
        return 1
    godot = find_godot(args.godot)
    if godot is None:
        print("Godot not found. Use --godot <path>, set GODOT_BIN, or put godot/godot4 in PATH.")
        return 2

    save_before = save_digest()
    results = []
    for test in tests:
        print("running %s ..." % test.stem, flush=True)
        results.append(run_one(godot, test, max(args.timeout, TIMEOUT_OVERRIDES.get(test.stem, 0))))
        last = results[-1]
        print("  -> %s (%d PASS, %d FAIL, %d error line(s), %.1fs)" % ("ok" if last["ok"] else "NOT OK", last["pass"], last["fail"], len(last["errors"]), last["seconds"]), flush=True)
    save_after = save_digest()

    width = max(len(r["name"]) for r in results)
    print()
    print("%-*s  %5s  %4s  %6s  %5s  %4s  %7s  %s" % (width, "test", "PASS", "FAIL", "ERRORS", "WARN", "exit", "seconds", "verdict"))
    print("-" * (width + 50))
    for r in results:
        verdict = "OK" if r["ok"] else ("TIMEOUT" if r["timed_out"] else "FAILED")
        print("%-*s  %5d  %4d  %6d  %5d  %4d  %7.1f  %s" % (width, r["name"], r["pass"], r["fail"], len(r["errors"]), r["warnings"], r["code"], r["seconds"], verdict))
    print("-" * (width + 50))
    print("%-*s  %5d  %4d  %6d" % (width, "total", sum(r["pass"] for r in results), sum(r["fail"] for r in results), sum(len(r["errors"]) for r in results)))

    failed = [r for r in results if not r["ok"]]
    for r in failed:
        print("\n--- %s ---" % r["name"])
        for line in r["errors"][:10]:
            print("  " + line)
        if args.verbose:
            print("\n".join("  " + line for line in r["output"].splitlines() if line.startswith(("FAIL", "ERROR", "SCRIPT"))))

    save_ok = True
    if save_before is None:
        print("\nReal save check: SKIPPED (user data folder could not be resolved safely).")
    else:
        save_ok = save_before == save_after
        print("\nReal save check: %s (%s -> %s)" % ("untouched" if save_ok else "CHANGED", save_before[:12], (save_after or "?")[:12]))

    verdict = not failed and save_ok
    print("OVERALL: %s (%d/%d tests ok)" % ("PASS" if verdict else "FAIL", len(results) - len(failed), len(results)))
    return 0 if verdict else 1


if __name__ == "__main__":
    sys.exit(main())
