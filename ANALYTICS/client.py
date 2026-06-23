#!/usr/bin/env python3
import json
import urllib.request

def post_json(api, path, payload):
    data = json.dumps(payload, separators=(",", ":"), allow_nan=False).encode()
    req = urllib.request.Request(api.rstrip("/") + path, data=data, headers={"Content-Type": "application/json"}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=8) as r:
            return r.getcode(), r.read().decode("utf-8", errors="ignore")[:600]
    except Exception as e:
        return 0, str(e)[:600]
