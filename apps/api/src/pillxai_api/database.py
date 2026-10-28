"""Shared transaction dependency; business modules own their tables and operations."""

from fastapi import Request
from sqlalchemy import MetaData

metadata = MetaData()


def transaction(request: Request):
    with request.app.state.engine.begin() as connection:
        yield connection


class BusinessError(Exception):
    def __init__(self, status: int, code: str, message: str):
        self.status, self.code, self.message = status, code, message


def not_found():
    raise BusinessError(404, "not_found", "未找到所请求的资料。")


def conflict():
    raise BusinessError(409, "revision_conflict", "资料已变化，请刷新后重新核对；当前草稿未保存。")
