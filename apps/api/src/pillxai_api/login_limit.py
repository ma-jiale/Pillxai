"""Bound total password-hashing work in the single-worker production process."""

from collections import deque
from time import monotonic

from starlette.responses import JSONResponse


class LoginLimit:
    def __init__(self, app, limit: int):
        self.app = app
        self.limit = limit
        self.attempts: deque[float] = deque()

    async def __call__(self, scope, receive, send):
        # Use the application-relative path, including behind a stripping proxy.
        path = scope.get("path", "")
        root = scope.get("root_path", "")
        if root and path.startswith(root + "/"):
            path = path[len(root):]
        if scope["type"] == "http" and scope["method"] == "POST" and path == "/auth/login":
            now = monotonic()
            while self.attempts and self.attempts[0] <= now - 60:
                self.attempts.popleft()
            # No await between checking and reserving: serialized on the ASGI loop.
            if len(self.attempts) >= self.limit:
                response = JSONResponse(
                    {"code": "login_rate_limited", "message": "登录请求较多，请稍后重试。"},
                    status_code=429, headers={"Retry-After": "60"},
                )
                await response(scope, receive, send)
                return
            self.attempts.append(now)
        await self.app(scope, receive, send)
