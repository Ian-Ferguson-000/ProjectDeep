"""Run the game's test suite with per-test timeouts and error-log detection.

Every file named <name>_test.gd anywhere under tests/ is a test. Run them all:

    python3 tools/run_hearth_tests.py --godot /path/to/godot

or just some, by name (no folder, no _test.gd):

    python3 tools/run_hearth_tests.py --godot /path/to/godot shop_floor trader

A test passes when Godot exits with code 0 and prints no "ERROR:" line.
Logs go to build/hearth_check_<name>.log. Old tests that no longer match the
game live in legacy/tests/ and are not run.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
TESTS = ROOT / "tests"


def find_tests() -> dict[str, Path]:
    """Every test by name -> its path relative to the project."""
    found = {}
    for path in sorted(TESTS.rglob("*_test.gd")):
        found[path.name[: -len("_test.gd")]] = path.relative_to(ROOT)
    return found


def run_one(godot: str, name: str, path: Path) -> tuple[str, bool, str]:
    try:
        run = subprocess.run(
            [godot, "--headless", "--path", str(ROOT), "--script", path.as_posix()],
            cwd=ROOT,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=45,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
        output = run.stdout + run.stderr
        ok = run.returncode == 0 and "ERROR:" not in output
    except subprocess.TimeoutExpired as error:
        output = "TIMEOUT\n" + str(error.stdout or "") + str(error.stderr or "")
        ok = False
    (ROOT / f"build/hearth_check_{name}.log").write_text(output, encoding="utf-8")
    return name, ok, output


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    parser.add_argument("--jobs", type=int, default=1, help="tests to run at once")
    parser.add_argument("--list", action="store_true", help="list the tests and stop")
    parser.add_argument("tests", nargs="*", help="test names; none = every test")
    args = parser.parse_args()

    tests = find_tests()
    if args.list:
        for name, path in tests.items():
            print(f"{name:40} {path}")
        return
    names = args.tests or list(tests)
    unknown = [name for name in names if name not in tests]
    if unknown:
        sys.exit("Unknown test(s): " + ", ".join(unknown))

    failed = []
    with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as pool:
        for name, ok, output in pool.map(lambda n: run_one(args.godot, n, tests[n]), names):
            print(f'{name}: {"PASS" if ok else "FAIL"}', flush=True)
            if not ok:
                failed.append(name)
                print(output[-2200:], flush=True)
    print(f"{len(names) - len(failed)}/{len(names)} passed", flush=True)
    sys.exit(bool(failed))


if __name__ == "__main__":
    main()
