"""Source binding controls only; no PS5/native/HTTP qualification is implied."""
import hashlib
from pathlib import Path
import re
import unittest

ROOT=Path(__file__).resolve().parents[1]


class SourceBinding(unittest.TestCase):
    def test_bootstrap_guard_bytes_cannot_drift_between_entry_and_helper(self):
        def guard(name):
            text=(ROOT/name).read_text()
            return text.split('# CODED_WINDOWS_EXPLICIT_QA_GUARD_V1',1)[1].split(
                '# END_CODED_WINDOWS_EXPLICIT_QA_GUARD_V1',1)[0]
        self.assertEqual(guard('run.ps1'),guard('run-windows.ps1'))

    def test_qa_pin_requires_this_guarded_helper_and_default_pin_stays_separate(self):
        text=(ROOT/'run.ps1').read_text()
        pins=re.findall(r"\$expected='([0-9a-f]{64})'",text)
        self.assertEqual(len(pins),2)
        self.assertEqual(pins[0],'d20a5825a54ff5e7672410349549b15c6be2d555d586010e5da4dd6fac022339')
        self.assertEqual(pins[1],hashlib.sha256((ROOT/'run-windows.ps1').read_bytes()).hexdigest())
        self.assertNotEqual(pins[0],pins[1])


if __name__=='__main__':unittest.main()
