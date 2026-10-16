"""CLI regression checks for the locally hardened HTTP JSON plugin."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

PLUGIN = Path(__file__).resolve().parents[1] / "check_http_json.rb"

@unittest.skipUnless(shutil.which("ruby"), "Ruby required")
class HttpJsonTests(unittest.TestCase):
    def run_plugin(self, payload, *args):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / "input.json"
            source.write_text(json.dumps(payload))
            return subprocess.run(
                ["ruby", str(PLUGIN), "-f", str(source), "-e", "value", *args],
                text=True, capture_output=True, timeout=10)

    def test_response_limit_spellings(self):
        for flag in ("--max_response_bytes", "--max-response-bytes"):
            with self.subTest(flag=flag):
                result = self.run_plugin({"value": "ok"}, "--result", "ok", flag, "2048")
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_invalid_response_limits(self):
        for flag in ("--max_response_bytes", "--max-response-bytes"):
            for limit in ("0", "-1"):
                with self.subTest(flag=flag, limit=limit):
                    result = self.run_plugin({"value": "ok"}, "--result", "ok", flag, limit)
                    self.assertEqual(result.returncode, 3)
                    self.assertIn("--max_response_bytes must be greater than zero", result.stdout)

    def test_long_output_escapes_perfdata_pipe(self):
        result = self.run_plugin({"value": "ok", "detail": "first|line\nsecond"},
                                 "--result", "ok", "--long_output", "detail")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout.splitlines()[1:], ["first!line", "second"])

    def test_missing_long_output_is_optional(self):
        result = self.run_plugin({"value": "ok"}, "--result", "ok", "--long_output", "absent")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(len(result.stdout.splitlines()), 1)

    def test_negative_decimal_threshold(self):
        result = self.run_plugin({"value": -1.5}, "--warn", "-10:10", "--crit", "-20:20")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_json_node_limit_retained(self):
        result = self.run_plugin({"value": "ok", "extra": [1, 2, 3]},
                                 "--result", "ok", "--max-json-elements", "2")
        self.assertEqual(result.returncode, 3)
        self.assertIn("JSON contains more than 2 elements", result.stdout)

    def test_json_depth_limit_retained(self):
        result = self.run_plugin({"value": "ok", "extra": {"nested": {"deep": 1}}},
                                 "--result", "ok", "--max-json-depth", "2")
        self.assertEqual(result.returncode, 3)
        self.assertIn("Parsing JSON failed", result.stdout)

if __name__ == "__main__":
    unittest.main()
