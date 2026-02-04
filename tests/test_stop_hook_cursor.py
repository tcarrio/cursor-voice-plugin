"""
Unit tests for the Cursor stop hook transcript parser.
Uses test data in tests/data/ (Cursor JSONL format) to validate behavior.
"""
import json
import sys
import unittest
from pathlib import Path

# Project root on path so we can import hooks
_ROOT = Path(__file__).resolve().parent.parent
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))

from hooks.stop_hook_cursor import (
    _extract_text_from_content,
    get_last_assistant_from_transcript_jsonl,
)

# Test data colocated with tests (Python convention: fixtures under test package)
_TESTS_DIR = Path(__file__).resolve().parent
EXAMPLE_TRANSCRIPT = _TESTS_DIR / "data" / "transcript.example.jsonl"


class TestExtractTextFromContent(unittest.TestCase):
    """Tests for _extract_text_from_content."""

    def test_empty_content(self):
        self.assertEqual(_extract_text_from_content([]), "")

    def test_none_content(self):
        self.assertEqual(_extract_text_from_content(None), "")

    def test_single_text_item(self):
        content = [{"type": "text", "text": "Hello world"}]
        self.assertEqual(_extract_text_from_content(content), "Hello world")

    def test_multiple_text_items_joined_with_newline(self):
        content = [
            {"type": "text", "text": "First"},
            {"type": "text", "text": "Second"},
        ]
        self.assertEqual(_extract_text_from_content(content), "First\nSecond")

    def test_skips_non_text_items(self):
        content = [
            {"type": "image", "url": "https://example.com/img.png"},
            {"type": "text", "text": "Only this"},
        ]
        self.assertEqual(_extract_text_from_content(content), "Only this")

    def test_skips_invalid_items(self):
        content = [{"type": "text", "text": "OK"}, "not a dict", None]
        self.assertEqual(_extract_text_from_content(content), "OK")


class TestGetLastAssistantFromTranscript(unittest.TestCase):
    """Tests for get_last_assistant_from_transcript_jsonl using example JSONL."""

    def test_example_file_returns_last_assistant_message(self):
        """Parse tests/data/transcript.example.jsonl; last line is assistant with summary."""
        result = get_last_assistant_from_transcript_jsonl(EXAMPLE_TRANSCRIPT)
        self.assertIsNotNone(result)
        # Last message in example is the "Summary of changes" block
        self.assertIn("Summary of changes", result)
        self.assertIn("JSONL parsing", result)
        self.assertIn("Result: the hook uses", result)

    def test_example_file_extracts_exactly_last_line(self):
        """Extracting from tests/data/transcript.example.jsonl returns the last line's text only."""
        # Get the last non-empty line from the example file and extract its text the same way the hook does
        lines = [
            ln.strip()
            for ln in EXAMPLE_TRANSCRIPT.read_text(encoding="utf-8").splitlines()
            if ln.strip()
        ]
        self.assertGreater(len(lines), 1, "example file should have multiple lines")
        last_line = lines[-1]
        obj = json.loads(last_line)
        expected = _extract_text_from_content(
            obj.get("message", {}).get("content") or []
        )
        self.assertTrue(expected, "last line should have extractable assistant text")
        result = get_last_assistant_from_transcript_jsonl(EXAMPLE_TRANSCRIPT)
        self.assertEqual(result, expected, "should return exactly the last line's extracted text")

    def test_example_file_returns_only_last_assistant_not_earlier(self):
        """Parser works from end of file; we get the final assistant message."""
        result = get_last_assistant_from_transcript_jsonl(EXAMPLE_TRANSCRIPT)
        self.assertIsNotNone(result)
        # Earliest assistant in example has "The user wants to fix the TTS output"
        # Last assistant has "Summary of changes" and "Removed Markdown heuristics"
        self.assertIn("Removed Markdown heuristics", result)
        self.assertIn("Removed debug write", result)

    def test_nonexistent_path_returns_none(self):
        result = get_last_assistant_from_transcript_jsonl(_TESTS_DIR / "nonexistent.jsonl")
        self.assertIsNone(result)

    def test_directory_path_returns_none(self):
        result = get_last_assistant_from_transcript_jsonl(_TESTS_DIR)
        self.assertIsNone(result)

    def test_empty_file_returns_none(self):
        with self.subTest("temp empty file"):
            import tempfile
            with tempfile.NamedTemporaryFile(
                mode="w", suffix=".jsonl", delete=False
            ) as f:
                pass
            try:
                result = get_last_assistant_from_transcript_jsonl(Path(f.name))
                self.assertIsNone(result)
            finally:
                Path(f.name).unlink(missing_ok=True)

    def test_only_user_lines_returns_none(self):
        import tempfile
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".jsonl", delete=False, encoding="utf-8"
        ) as f:
            f.write('{"role":"user","message":{"content":[{"type":"text","text":"Hi"}]}}\n')
        try:
            result = get_last_assistant_from_transcript_jsonl(Path(f.name))
            self.assertIsNone(result)
        finally:
            Path(f.name).unlink(missing_ok=True)

    def test_single_assistant_line(self):
        import tempfile
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".jsonl", delete=False, encoding="utf-8"
        ) as f:
            f.write('{"role":"assistant","message":{"content":[{"type":"text","text":"Done."}]}}\n')
        try:
            result = get_last_assistant_from_transcript_jsonl(Path(f.name))
            self.assertEqual(result, "Done.")
        finally:
            Path(f.name).unlink(missing_ok=True)


if __name__ == "__main__":
    unittest.main()
