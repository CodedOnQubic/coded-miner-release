"""Run the real bootstrap argument parser without downloads or mining."""
import os
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


class MacNeonArguments(unittest.TestCase):
    def run_parser(self, args, resume=False):
        source = (ROOT / 'run-macos.sh').read_text().split('channel_url=', 1)[0]
        source += '\nprintf "%s|%s|%s" "$backend" "$threads" "$channel"\n'
        source = 'uname() { case "$1" in -s) echo Darwin;; -m) echo arm64;; esac; }\n' + source
        env = {'PATH': '/usr/bin:/bin', 'WALLET': 'A' * 60, 'WORKER': 'Neon_QA'}
        if resume:
            env['CODED_MACOS_SAME_LAYOUT_RESUME'] = '/not-an-execution-authorization'
        return subprocess.run(['/bin/bash', '-s', '--', *args], input=source,
                              text=True, capture_output=True, env=env)

    def test_neon_both_channels_and_threads(self):
        for channel in ('beta', 'latest'):
            for selector in (['--backend=neon'], ['--backend', 'neon']):
                for count in (0, 8, 11):
                    result = self.run_parser(['--' + channel, *selector, '--threads', str(count)])
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout, f'neon|{count}|{channel}')

    def test_existing_auto_is_preserved(self):
        for args in ([], ['--backend=mac'], ['--backend=auto'], ['-auto']):
            result = self.run_parser(args)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, 'mac|0|latest')

    def test_invalid_and_conflicting_modes_still_denied(self):
        for args in (['--backend=metal'], ['--backend=hybrid'], ['--backend=cuda'],
                     ['--backend=neon', '--backend=mac'], ['-gpu'], ['-gpu_only'],
                     ['--backend=neon', '--threads', '1025'], ['--threads', '-1']):
            self.assertNotEqual(self.run_parser(args).returncode, 0, args)

    def test_existing_upgrade_lane_parser_is_preserved(self):
        for lane in ('neon', 'metal', 'hybrid'):
            result = self.run_parser(['--backend=' + lane], resume=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, lane + '|0|latest')


if __name__ == '__main__':
    unittest.main()
