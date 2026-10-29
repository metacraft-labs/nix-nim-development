"""Exercise the archive utility on real files and real packaged compiler output.

Malformed JSON fixtures test the utility's own input contract, rather than mock
a compiler. The integration control compiles/runs actual C and generates actual
JS, preserving its source, commands, logs, cache, object and executable evidence.
"""
import argparse
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

from normalize_check_artifacts import EPOCH, POLICY, TIMESTAMP, finalize


class MetadataTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.output = self.root / "program"
        self.output.write_bytes(b"\x00\xffactual retained bytes\n")
        self.output.chmod(0o755)
        os.utime(self.output, (1700000000, 1700000000))
        self.metadata = {
            "cacheVersion": "D20240927T193831",
            "outputFile": str(self.output),
            "outputLastModificationTime": "2023-11-14T22:13:20+00:00",
            "compile": [["source.c", "gcc source.c"]],
            "link": ["source.o"], "linkcmd": "gcc source.o",
            "other": {"timestamp": "2023-11-14T22:13:20+00:00"},
        }
        self.cache = self.root / "program.json"
        self.write_cache()

    def write_cache(self):
        self.cache.write_text(json.dumps(self.metadata, indent=2) + "\n")

    def test_only_recorded_timestamp_bytes_change(self):
        raw = self.cache.read_bytes()
        artifact = self.output.read_bytes()
        unrelated = self.root / "receipt.json"
        unrelated.write_text('{"receipt": "2023-11-14T22:13:20+00:00"}\n')
        self.assertEqual(finalize(self.root), 1)
        expected = raw.replace(
            b'"outputLastModificationTime": "2023-11-14T22:13:20+00:00"',
            b'"outputLastModificationTime": "1970-01-01T00:00:01+00:00"',
        )
        self.assertNotEqual(raw, expected)
        self.assertEqual(self.cache.read_bytes(), expected)
        self.assertEqual(self.output.read_bytes(), artifact)
        self.assertEqual(self.output.stat().st_mode & 0o777, 0o755)
        self.assertEqual(self.output.stat().st_mtime_ns, EPOCH * 1000000000)
        self.assertEqual(unrelated.read_text(), '{"receipt": "2023-11-14T22:13:20+00:00"}\n')
        self.assertIn("cache-records=1\noutputs=1\ntimestamp-records=1", (self.root / POLICY).read_text())
        before = contents(self.root)
        finalize(self.root)
        self.assertEqual(contents(self.root), before)

    def test_empty_timestamp_stays_empty(self):
        self.metadata["outputLastModificationTime"] = ""
        self.write_cache()
        before = self.cache.read_bytes()
        finalize(self.root)
        self.assertEqual(self.cache.read_bytes(), before)
        self.assertIn("timestamp-records=0", (self.root / POLICY).read_text())

    def test_compiler_local_timezone_is_supported(self):
        self.metadata["outputLastModificationTime"] = "2023-11-15T00:13:20+02:00"
        self.write_cache()
        finalize(self.root)
        self.assertEqual(json.loads(self.cache.read_bytes())["outputLastModificationTime"], TIMESTAMP)

    def test_corrupt_timestamp_is_refused_before_any_mutation(self):
        corrupt = self.root / "z-corrupt.json"
        invalid = dict(self.metadata, outputLastModificationTime="2023-11-14T22:13:21+00:00")
        corrupt.write_text(json.dumps(invalid))
        before = contents(self.root)
        mtime = self.output.stat().st_mtime_ns
        with self.assertRaisesRegex(ValueError, "disagrees"):
            finalize(self.root)
        self.assertEqual(contents(self.root), before)
        self.assertEqual(self.output.stat().st_mtime_ns, mtime)

    def test_missing_output_is_refused(self):
        self.output.unlink()
        with self.assertRaises(FileNotFoundError):
            finalize(self.root)

    def test_out_of_archive_output_is_refused(self):
        self.metadata["outputFile"] = str(Path(__file__).resolve())
        self.write_cache()
        with self.assertRaisesRegex(ValueError, "escapes"):
            finalize(self.root)

    def test_output_symlink_is_refused(self):
        alias = self.root / "alias"
        alias.symlink_to(self.output)
        self.metadata["outputFile"] = str(alias)
        self.write_cache()
        with self.assertRaisesRegex(ValueError, "absolute regular"):
            finalize(self.root)

    def test_cache_symlink_is_refused(self):
        original = self.root / "data.txt"
        self.cache.rename(original)
        self.cache.symlink_to(original)
        with self.assertRaisesRegex(ValueError, "absolute regular"):
            finalize(self.root)

    def test_escaped_duplicate_key_is_refused(self):
        raw = self.cache.read_bytes().replace(
            b'"outputLastModificationTime":',
            b'"outputLastModification\\u0054ime": "", "outputLastModificationTime":',
        )
        self.cache.write_bytes(raw)
        with self.assertRaisesRegex(ValueError, "Duplicate cache key"):
            finalize(self.root)

    def test_escaped_timestamp_key_is_refused(self):
        self.cache.write_bytes(self.cache.read_bytes().replace(
            b'"outputLastModificationTime":', b'"outputLastModification\\u0054ime":',
        ))
        with self.assertRaisesRegex(ValueError, "Ambiguous"):
            finalize(self.root)

    def test_malformed_metadata_is_refused(self):
        self.cache.write_text('{"outputLastModificationTime":')
        with self.assertRaisesRegex(ValueError, "Malformed"):
            finalize(self.root)

    def test_malformed_escaped_cache_is_not_skipped(self):
        (self.root / "z-corrupt.json").write_bytes(b'{"outputLastModification\\u0054ime":')
        before = contents(self.root)
        with self.assertRaisesRegex(ValueError, "Malformed"):
            finalize(self.root)
        self.assertEqual(contents(self.root), before)

    def test_non_json_numeric_constants_are_refused(self):
        for value in [float("nan"), float("inf"), float("-inf")]:
            with self.subTest(value=value):
                self.metadata["other"] = value
                self.write_cache()
                before = contents(self.root)
                with self.assertRaisesRegex(ValueError, "Malformed"):
                    finalize(self.root)
                self.assertEqual(contents(self.root), before)

    def test_unexpected_timestamp_format_is_refused(self):
        self.metadata["outputLastModificationTime"] = "yesterday"
        self.write_cache()
        with self.assertRaisesRegex(ValueError, "Unsupported"):
            finalize(self.root)

    def test_schema_mismatch_is_refused(self):
        del self.metadata["linkcmd"]
        self.write_cache()
        with self.assertRaisesRegex(ValueError, "schema"):
            finalize(self.root)

    def test_empty_census_is_refused(self):
        self.cache.unlink()
        with self.assertRaisesRegex(ValueError, "No retained"):
            finalize(self.root)


def contents(root):
    """Read actual file bytes for an independent whole-tree preservation check."""
    return {str(path.relative_to(root)): path.read_bytes()
            for path in root.rglob("*") if path.is_file()}


def compile_outputs(nim, output, backends):
    """Retain sources, commands and logs for actual packaged compiler runs."""
    output.mkdir(parents=True, exist_ok=False)
    source = output / "subject.nim"
    source.write_text('echo "retained compiler evidence"\n')
    commands = []
    for backend in backends:
        command = [
            str(nim), backend, "--hints:off", "--colors:off",
            "--nimcache:" + str(output / (backend + "-cache")),
            "--out:" + str(output / ("subject" if backend == "c" else "subject.js")),
        ]
        if backend == "c":
            command += ["--mm:arc", "--run"]
        command += [str(source)]
        commands.append(command)
        with (output / (backend + ".log")).open("w") as log:
            subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True)
    (output / "commands.json").write_text(json.dumps(commands, indent=2) + "\n")
    if (output / "c.log").read_text() != "retained compiler evidence\n":
        raise AssertionError("Real native program did not produce its required runtime output")


def recorded_timestamp(output):
    """Require an actual compiler-recorded output time before any finalization."""
    cache = output / "c-cache/subject.json"
    timestamp = json.loads(cache.read_bytes())["outputLastModificationTime"]
    if not timestamp or timestamp == TIMESTAMP:
        raise AssertionError("Real compiler control did not record a noncanonical timestamp")
    if int(datetime.fromisoformat(timestamp).timestamp()) != int((output / "subject").stat().st_mtime):
        raise AssertionError("Real compiler timestamp disagrees with its actual native output")
    return timestamp


def compiler_control(nim, output):
    """Use real compiler-generated metadata and retain all integration evidence."""
    compile_outputs(nim, output, ["c", "js"])
    if not (output / "subject.js").is_file():
        raise AssertionError("Real JS compiler output missing")
    before = contents(output)
    cache = output / "c-cache/subject.json"
    timestamp = recorded_timestamp(output)
    finalize(output)
    after = contents(output)
    expected = dict(before)
    expected["c-cache/subject.json"] = before["c-cache/subject.json"].replace(
        json.dumps(timestamp).encode(), json.dumps(TIMESTAMP).encode(), 1,
    )
    expected[POLICY] = after[POLICY]
    if after != expected:
        raise AssertionError("Archive finalization changed non-timestamp evidence bytes")
    if json.loads(cache.read_bytes())["outputLastModificationTime"] != TIMESTAMP:
        raise AssertionError("Real compiler cache timestamp was not canonicalized")
    if (output / "subject").stat().st_mtime_ns != EPOCH * 1000000000:
        raise AssertionError("Real compiler output mtime was not canonicalized")
    finalize(output)
    if contents(output) != after:
        raise AssertionError("Archive finalization is not idempotent")
    (output / "compiler.sha256").write_text(
        hashlib.sha256(nim.resolve().read_bytes()).hexdigest() + "\n",
    )


class RetainedTestResult(unittest.TestResult):
    """Retain each verdict and full failures without generating wall timings."""
    def addSuccess(self, test):
        super().addSuccess(test)
        print(f"PASS {test.id()}")

    def addFailure(self, test, error):
        super().addFailure(test, error)
        print(f"FAIL {test.id()}")

    def addError(self, test, error):
        super().addError(test, error)
        print(f"ERROR {test.id()}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--nim", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(MetadataTests)
    expected = suite.countTestCases()
    result = RetainedTestResult()
    suite.run(result)
    for test, traceback in result.errors + result.failures:
        print(f"{test.id()}\n{traceback}")
    print(f"Executed {result.testsRun} metadata tests")
    if (not expected or result.testsRun != expected or not result.wasSuccessful()
            or result.skipped or result.expectedFailures or result.unexpectedSuccesses):
        raise SystemExit(1)
    compiler_control(args.nim, args.output.resolve() / "compiler-control")
    print("PASS real C runtime / JS output preservation and timestamp canonicalization")
    # This distinct real compilation remains raw here. Only the common flake
    # check wrapper may finalize it, exercising the same route as other checks.
    pending = args.output.resolve() / "wrapper-control"
    compile_outputs(args.nim, pending, ["c"])
    recorded_timestamp(pending)
    print("PASS real raw C runtime evidence retained for the common archive wrapper")
