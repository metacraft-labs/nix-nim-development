"""Validate actual complete Nix catalog identities; no mocked evaluator.

The negative control removes checks from the real evaluated flake, rather than
inventing a successful inventory. It must be rejected by the same validator.
"""
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SYSTEMS = ["x86_64-linux", "aarch64-darwin"]


def validate(data):
    for system in SYSTEMS:
        packages = data[system]["packages"]
        checks = data[system]["checks"]
        if not packages or not checks or packages != checks:
            raise ValueError("Missing or different complete CI derivations for " + system)
        if any(not value.endswith(".drv") for value in packages.values()):
            raise ValueError("Catalog contains a non-derivation identity")


def evaluate(remove_checks=False):
    flake = "git+file://" + str(ROOT)
    expression = ('let original = builtins.getFlake ' + json.dumps(flake) + '; '
                  + 'f = ' + ('builtins.removeAttrs original ["checks"]' if remove_checks else 'original')
                  + '; systems = ["x86_64-linux" "aarch64-darwin"]; '
                  + 'identity = set: builtins.mapAttrs (name: value: value.drvPath) set; '
                  + 'in builtins.listToAttrs (map (system: { name = system; value = '
                  + '{ packages = identity (f.packages.${system} or {}); '
                  + 'checks = identity (f.checks.${system} or {}); }; }) systems)')
    result = subprocess.run(["nix", "--extra-experimental-features", "nix-command flakes",
                             "eval", "--impure", "--json", "--expr", expression],
                            capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stderr)
    return json.loads(result.stdout)


if __name__ == "__main__":
    actual = evaluate()
    validate(actual)
    try:
        validate(evaluate(remove_checks=True))
    except ValueError:
        pass
    else:
        raise AssertionError("Real missing-checks negative control unexpectedly passed")
    print(json.dumps(actual, indent=2))
