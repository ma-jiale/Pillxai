"""Read-only host/V1 evidence. No environment variables or credentials are printed."""

import json
import os
import shutil
import subprocess
import urllib.request
from pathlib import Path

root = Path.home() / "projects/pillxa-dispenser"
probe = root if root.exists() else Path.home()
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
with opener.open("http://127.0.0.1:5068/__deployment_health", timeout=10) as response:
    if response.status != 200:
        raise SystemExit("V1 baseline unhealthy")
    json.load(response)
containers = subprocess.run(
    [
        "docker",
        "ps",
        "--filter",
        "label=com.docker.compose.project=pillxa-v1",
        "--format",
        "{{.ID}} {{.Status}} {{.Ports}}",
    ],
    check=True,
    capture_output=True,
    text=True,
).stdout.strip()
if not containers:
    raise SystemExit("Expected V1 project is not running")
memory = {}
for line in Path("/proc/meminfo").read_text().splitlines():
    name, value = line.split(":", 1)
    if name in {"MemTotal", "MemAvailable"}:
        memory[name] = int(value.split()[0]) // 1024
print(
    json.dumps(
        {
            "v1_health": "ok",
            "v1_containers": containers,
            "memory_mib": memory,
            "cpu_count": os.cpu_count(),
            "free_disk_gib": round(shutil.disk_usage(probe).free / 1024**3, 1),
        }
    )
)
if memory.get("MemAvailable", 0) < 4096:
    raise SystemExit(
        "Less than 4 GiB available; review coexistence resource limits before deployment"
    )
