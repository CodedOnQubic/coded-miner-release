#!/usr/bin/env python3
"""Mac-only exact-archive bootstrap tests. Stage only; never starts a miner."""
import argparse
import copy
import hashlib
import http.server
import json
import os
from pathlib import Path
import subprocess
import tempfile
import threading

ROOT=Path(__file__).resolve().parents[1]


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--package',type=Path,required=True)
    args=parser.parse_args()
    manifest=json.loads((args.package/'release_manifest.json').read_text())
    pin=manifest['source_commit']; version=manifest['version']
    archive=args.package/'coded-miner-macos-arm64-beta-latest.tar.gz'
    digest=hashlib.sha256(archive.read_bytes()).hexdigest()
    original={'beta':{'commit':pin,'version':version,'status':'completed','stage':'complete','assets':{'macos':{'ok':True}}}}
    current=copy.deepcopy(original)
    mismatch=False
    requests=[]
    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            requests.append(self.path)
            base='http://127.0.0.1:'+str(self.server.server_port)
            if self.path=='/channel': data=json.dumps(current).encode()
            elif self.path=='/tags/'+version:
                data=json.dumps({'assets':[{'name':archive.name,'digest':'sha256:'+('0'*64 if mismatch else digest),
                    'browser_download_url':base+'/download/'+version+'/'+archive.name}]}).encode()
            elif self.path=='/download/'+version+'/'+archive.name: data=archive.read_bytes()
            else: self.send_error(404); return
            self.send_response(200);self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data)
        def log_message(self,*args): pass
    server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler)
    threading.Thread(target=server.serve_forever,daemon=True).start()
    base='http://127.0.0.1:'+str(server.server_port)
    reports=[]
    try:
        with tempfile.TemporaryDirectory(prefix='coded-mac-bootstrap-test-') as temporary:
            root=Path(temporary)
            env=dict(PATH='/usr/bin:/bin:/usr/sbin:/sbin',HOME=str(root),TMPDIR=str(root),
                CODED_ALLOW_FEATURE_VALIDATION='1',CODED_ANT_V3_LIVE_SUBMIT='0',CODED_MAC_STAGE_ONLY='1',
                CODED_MAC_CHANNEL_URL=base+'/channel',CODED_MAC_RELEASE_API=base+'/tags',CODED_MAC_DOWNLOAD_BASE=base+'/download')
            def run(name,success,cache):
                result=subprocess.run(['/bin/bash',str(ROOT/'run-macos.sh'),'--beta','--wallet','A'*60,'--worker','Fixture'],
                    env=dict(env,CODED_MAC_PACKAGE_CACHE=str(cache)),capture_output=True,text=True,timeout=60)
                assert (result.returncode==0)==success,(name,result.stdout,result.stderr)
                assert 'CODED Mac source=' not in result.stdout,'stage-only started supervisor'
                reports.append({'case':name,'result':'PASS','exit_code':result.returncode})
            for name,mutate in (
                ('missing-mac-asset',lambda d:d['beta']['assets']['macos'].update(ok=False)),
                ('incomplete-channel',lambda d:d['beta'].update(stage='building')),
                ('disabled-beta',lambda d:d.update(beta_disabled={'disabled':True,'commit':pin})),
                ('ambiguous-source',lambda d:d['beta'].update(commit='bad-short-sha'))):
                current=copy.deepcopy(original);mutate(current)
                before=len(requests);run(name,False,root/name)
                assert requests[before:]==['/channel'],'failed metadata still downloaded asset'
            current=copy.deepcopy(original);mismatch=True
            run('archive-digest-mismatch',False,root/'bad-digest')
            mismatch=False
            cache=root/'valid'
            run('stock-tools-stage-only',True,cache)
            before=len(requests)
            run('verified-cache-reuse',True,cache)
            assert requests[before:]==['/channel'],'valid cache unexpectedly downloaded asset'
            file=cache/version/'coded-miner/coded-public-console.py'
            file.write_bytes(file.read_bytes()+b'\n# deliberate test-only cache corruption\n')
            damaged=file.read_bytes()
            run('damaged-cache-preserved-fail-closed',False,cache)
            assert file.read_bytes()==damaged,'damaged evidence was deleted or overwritten'
    finally:
        server.shutdown();server.server_close()
    print(json.dumps({'result':'PASS','archive_sha256':digest,'source_commit':pin,
        'stage_only':True,'miner_started':False,'cases':reports},indent=2))


if __name__=='__main__': main()
