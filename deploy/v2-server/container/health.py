import json
import os
import urllib.request

with urllib.request.urlopen("http://127.0.0.1:8000/health/ready", timeout=4) as response:
    health = json.load(response)
if health != {"status": "ready", "service_version": os.environ["PILLXAI_SERVICE_VERSION"]}:
    raise SystemExit("Unexpected readiness response")
