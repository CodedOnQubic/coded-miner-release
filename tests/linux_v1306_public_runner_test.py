#!/usr/bin/env python3
"""Exercise the real pinned runner transform; only argument sections execute."""
import importlib.util
import hashlib
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('patcher', ROOT/'runtime/run-v5-patch.py')
patcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(patcher)


class PublicLinux(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        core = subprocess.check_output(['git', '-C', str(ROOT), 'show',
            'd8ddc3f38a105233a6327920373a3ebb2939a55f:run.sh'], text=True)
        cls.text = patcher.transform(core, 'https://example.invalid/not-downloaded')
        cls.args = cls.text[cls.text.index('# CODED_LINUX_V1306_PUBLIC_ARGUMENTS'):
                             cls.text.index('\nWALLET="${WALLET:-${QUBIC_WALLET:-${CODED_WALLET:-}}}"')]

    def test_real_runner_shell_syntax_and_owned_lifecycle(self):
        subprocess.run(['bash', '-n'], input=self.text, text=True, check=True)
        self.assertEqual(self.text.count('coded_public_autoupdate_start()'), 1)
        self.assertIn('export CODED_MINER_PID="$MINER_PID"', self.text)
        self.assertIn('CODED_ANALYTICS2_REQUIRE_PID_ELF=1', self.text)
        self.assertIn('CODED_ROUTER_PROFILE=ant_v3_live', self.text)
        self.assertIn('CODED_RUNTIME_SIDECAR_PARENT_PID="$$"', self.text)
        self.assertIn('CODED_MINER_COMMIT="$CODED_SOURCE_COMMIT"', self.text)
        self.assertIn('--lease-fd 207', self.text)

    def test_argument_matrix(self):
        for args, expected in [([], 'auto|auto|0'), (['-cuda'], 'cuda|auto|0'),
                (['-avx2','-cuda'], 'hybrid|avx2|0'),
                (['-cuda','-avx512'], 'hybrid|avx512|0'), (['-31'], 'auto|auto|1'),
                (['--threads=8','-cuda'], 'cuda|auto|1')]:
            script = 'BACKEND=auto\nTHREADS=0\n'+self.args+'\nprintf "%s|%s|%s" "$BACKEND" "$CODED_PUBLIC_CPU_REQUEST" "$CODED_PUBLIC_THREADS_EXPLICIT"\n'
            result = subprocess.run(['bash', '-s', '--', *args], input=script, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, expected)

    def test_retired_gpu_arguments_fail_closed(self):
        for args in (['-gpu'], ['-gpu_only'], ['-avx2','-gpu'], ['-avx512','-gpu_only']):
            result = subprocess.run(['bash', '-s', '--', *args], input='BACKEND=auto\nTHREADS=0\n'+self.args, text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)

    def test_mac_helper_pin_and_latest_isolation(self):
        import re
        root=(ROOT/'run.sh').read_text()
        pin=re.search(r'mac_bootstrap_commit=([0-9a-f]{40})',root).group(1)
        expected=re.search(r'mac_bootstrap_sha=([0-9a-f]{64})',root).group(1)
        helper=subprocess.check_output(['git','-C',str(ROOT),'show',pin+':run-macos.sh'])
        self.assertEqual(hashlib.sha256(helper).hexdigest(),expected)
        self.assertIn('"$coded_mac_native_beta" == 1',root)
        self.assertIn('beta_disabled.disabled',helper.decode())

    def test_manifest_bound_cuda_profile_replaces_inherited_values(self):
        begin=self.text.index('  # CODED_LINUX_V1306_CUDA_PROFILE:')
        end=self.text.index('  # CODED_LINUX_V1306_CUDA_PROFILE_END',begin)
        block=self.text[begin:end]
        import json
        for enabled in (None,False,True):
            manifest={'population':32,'cuda_default_workers':8,'cuda_default_threads_per_block':32 if enabled else 64}
            if enabled is not None:
                manifest['cuda_optimized_profile']={'schema':'coded.cuda.p32-build-profile.v1','enabled':enabled,
                    'threads_per_block':32 if enabled else 64,'large_batch_collection_cap_ms':120 if enabled else 60,
                    **{key:enabled for key in ('register_state','fixed_point','exact_cycle','packed_lut','undo_mutations','cycle_index')},
                    'cpu_geometry_changed':False,'cuda_geometry_changed':False,'hardware_qualification_implied':False}
                manifest['hybrid_profile']={'partial_flush_ms':120 if enabled else 60}
            with tempfile.TemporaryDirectory(prefix='coded-public-cuda-profile-') as d:
                path=Path(d)/'release_manifest.json'
                def execute(value):
                    path.write_text(json.dumps(value))
                    return subprocess.run(['bash','-c',block+'\nprintf "%s,%s,%s" "$CODED_CUDA_WORKERS" "$CODED_CUDA_V1306_THREADS" "${CODED_CUDA_BATCH_WAIT_MS:-compiled-default}"'],
                        env=dict(__import__('os').environ,INSTALL_DIR=d,CODED_CUDA_V1306_THREADS='64',CODED_CUDA_BATCH_WAIT_MS='240'),
                        capture_output=True,text=True)
                good=execute(manifest)
                self.assertEqual(good.returncode,0,good.stderr)
                self.assertEqual(good.stdout,'8,32,compiled-default' if enabled else '8,64,compiled-default')
                for key,value in (('cuda_default_workers',512),('cuda_default_threads_per_block',32 if not enabled else 64)):
                    bad=execute(dict(manifest,**{key:value}))
                    self.assertNotEqual(bad.returncode,0)
                if enabled:
                    self.assertNotEqual(execute(dict(manifest,population=64)).returncode,0)

    def test_explicit_mac_routes_both_channels_without_replacing_legacy_latest(self):
        root=(ROOT/'run.sh').read_text().split('CODED_PUBLIC_RUNNER_BASE_COMMIT=',1)[0]
        with tempfile.TemporaryDirectory(prefix='coded-mac-root-route-') as d:
            helper=Path(d)/'helper.sh';helper.write_text('printf "NATIVE:%s" "$*"\n')
            script='uname() { case "$1" in -s) echo Darwin;; -m) echo arm64;; esac; }\n'+root+'\necho LEGACY_PATH\n'
            env=dict(__import__('os').environ,CODED_ALLOW_FEATURE_VALIDATION='1',CODED_MAC_BOOTSTRAP_LOCAL=str(helper))
            for args in (['--beta'],['--latest','--backend=mac'],['--backend','mac','--latest']):
                result=subprocess.run(['bash','-s','--',*args],input=script,env=env,capture_output=True,text=True)
                self.assertEqual(result.returncode,0,result.stderr)
                self.assertIn('NATIVE:',result.stdout)
                self.assertNotIn('LEGACY_PATH',result.stdout)
            result=subprocess.run(['bash','-s','--','--latest'],input=script,env=env,capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertIn('LEGACY_PATH',result.stdout)


if __name__ == '__main__': unittest.main()
