import os

import uvicorn

# One process: login budget and graceful shutdown have a single owner.
uvicorn.run(
    "pillxai_api.app:create_app",
    factory=True,
    host="0.0.0.0",
    port=8000,
    workers=1,
    proxy_headers=True,
    forwarded_allow_ips=os.environ.get("V2_FORWARDED_ALLOW_IPS", "127.0.0.1"),
    timeout_graceful_shutdown=30,
    access_log=False,
)
