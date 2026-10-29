"""Build and force-rebuild real package checks, comparing their complete NARs.

No compiler, filesystem, or Nix evaluator is mocked. Nix's --rebuild comparison
is the oracle; a successful behavior run alone cannot satisfy this test.
"""
import argparse
from pathlib import Path
import subprocess
import time


ROOT = Path(__file__).resolve().parents[1]
CHECKS = ["nim-ownership", "nim-symbol-owner", "nim-artifact-retention"]


def verify(check, system, output):
    """Retain both logs and fail on any build or byte-comparison failure."""
    target = f"{ROOT}#checks.{system}.{check}"
    # Freeze the derivation before either build: an edit or branch update while
    # a long check runs must not compare two different evaluated recipes.
    evaluated = subprocess.run(
        ["nix", "eval", "--raw", target + ".drvPath"],
        capture_output=True, text=True, check=True,
    )
    derivation = evaluated.stdout
    if not derivation.startswith("/nix/store/") or not derivation.endswith(".drv"):
        raise RuntimeError("Nix did not return a derivation identity: " + derivation)
    (output / f"{check}-derivation.txt").write_text(derivation + "\n")
    command = [
        "nix", "build", derivation + "^*", "--no-link", "--print-out-paths",
        "--max-jobs", "1", "--cores", "2", "--builders", "", "-L",
    ]
    for phase, extra in [("build", []), ("rebuild", ["--rebuild", "--keep-failed"])]:
        if phase == "rebuild":
            # Nim records whole seconds. Separate the real builds so a missing
            # timestamp finalizer cannot self-pass by finishing in one second.
            time.sleep(1.1)
        log = output / f"{check}-{phase}.log"
        with log.open("w") as stream:
            result = subprocess.run(command + extra, stdout=stream, stderr=subprocess.STDOUT)
        if result.returncode:
            raise RuntimeError(f"{check} {phase} failed ({result.returncode}); see {log}")
    retained = subprocess.run(
        ["nix", "path-info", derivation + "^*"],
        capture_output=True, text=True, check=True,
    )
    paths = retained.stdout.splitlines()
    if len(paths) != 1:
        raise RuntimeError("Expected one retained check output")
    policy = (Path(paths[0]) / "artifact-retention.txt").read_text()
    fields = dict(line.split("=", 1) for line in policy.splitlines() if "=" in line)
    if fields.get("epoch") != "1" or any(int(fields.get(key, "0")) <= 0 for key in ["cache-records", "outputs"]):
        raise RuntimeError("Missing nonempty canonical archive policy census for " + check)
    print(f"PASS complete Nix output comparison: {check}", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="append", choices=CHECKS)
    parser.add_argument("--system", default="x86_64-linux")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    for name in args.check or CHECKS:
        verify(name, args.system, args.output)
