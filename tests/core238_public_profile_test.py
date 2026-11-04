"""Run the actual public runner's profile guard; never execute a miner."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('public_patch',ROOT/'runtime/run-v5-patch.py')
patch=importlib.util.module_from_spec(spec);spec.loader.exec_module(patch)

class Core238PublicProfile(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        core=subprocess.check_output(['git','-C',str(ROOT),'show','d8ddc3f38a105233a6327920373a3ebb2939a55f:run.sh'],text=True)
        transformed=patch.transform(core,'https://example.invalid/not-downloaded')
        subprocess.run(['bash','-n'],input=transformed,text=True,check=True)
        cls.guard=transformed.split("<<'PYCUDAPROFILE'\n",1)[1].split('\nPYCUDAPROFILE',1)[0]
        cls.manifest=json.loads((ROOT/'tests/fixtures/core238-812b-public-profile.json').read_text())

    def run_guard(self,manifest):
        with tempfile.TemporaryDirectory(prefix='coded-public238-')as directory:
            p=Path(directory)/'manifest.json';p.write_text(json.dumps(manifest))
            return subprocess.run([sys.executable,'-B','-',str(p)],input=self.guard,text=True,capture_output=True)

    def test_exact_core238_profile_and_actual_final_manifest(self):
        manifests=[self.manifest]
        if os.environ.get('CODED_PUBLIC_PROFILE_MANIFEST'):
            manifests.append(json.loads(Path(os.environ['CODED_PUBLIC_PROFILE_MANIFEST']).read_text()))
        for manifest in manifests:
            result=self.run_guard(manifest)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertIn('export CODED_CUDA_WORKERS=512',result.stdout)
            self.assertIn('export CODED_CUDA_V1306_THREADS=32',result.stdout)
            self.assertIn('unset CODED_CUDA_BATCH_WAIT_MS',result.stdout)

    def test_source_core_build_algorithm_and_geometry_tampering_refused(self):
        changes={'source_commit':['b'*40],'commit':['b'*40],'core_profile':[237,239,'238',True],
            'core_commit':['4fc13712e26567ad24bf6ec62ec41aab9e02cec7'],
            'algorithm_generation':['0'*64],'task_sha256':['0'*64],
            'population':[64,True],'ann_bytes':[2176],'advance_threshold':[2921],
            'cuda_default_workers':[8,'512',True],'cuda_architectures':[[86,121],['86','120']],
            'cuda_default_threads_per_block':[64],
            'preparation_only':[True],'publishable_source':[False]}
        for key,values in changes.items():
            for value in values:
                with self.subTest(key=key,value=value):
                    bad=copy.deepcopy(self.manifest);bad[key]=value
                    self.assertNotEqual(self.run_guard(bad).returncode,0)

    def test_authority_tampering_and_missing_fields_refused(self):
        binding=self.manifest['work_authority_build']
        changes={'schema':['wrong'],'required':[False],'test_only_package':[True],
            'core_profile':[237,239,'238',True],'source_commit':['b'*40],
            'core_commit':['4fc13712e26567ad24bf6ec62ec41aab9e02cec7'],
            'algorithm_generation':['0'*64],'build_authority_id':['0'*64],
            'contract_sha256':['0'*64],'issuer_key_id':['0'*64],
            'task_sha256':['0'*64],'population':[64,True],'ann_bytes':[2176]}
        for key,values in changes.items():
            for value in values:
                with self.subTest(key=key,value=value):
                    bad=copy.deepcopy(self.manifest);bad['work_authority_build'][key]=value
                    self.assertNotEqual(self.run_guard(bad).returncode,0)
        for key in binding:
            if key=='qualification':continue
            with self.subTest(missing=key):
                bad=copy.deepcopy(self.manifest);del bad['work_authority_build'][key]
                self.assertNotEqual(self.run_guard(bad).returncode,0)

    def test_mixed_cta_profile_tampering_refused(self):
        for key,value in [('schema','coded.cuda.p32-build-profile.v1'),('enabled',False),
                ('requested_walks_per_block',1),('neuron_threads_per_walk',64),
                ('physical_threads_per_cta',{'sm86':128,'sm120':32,'unknown':32})]:
            with self.subTest(key=key):
                bad=copy.deepcopy(self.manifest);bad['cuda_optimized_profile'][key]=value
                self.assertNotEqual(self.run_guard(bad).returncode,0)

if __name__=='__main__':unittest.main()
