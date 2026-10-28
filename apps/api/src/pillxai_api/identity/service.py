import secrets
from datetime import UTC, datetime, timedelta
from typing import Annotated
from uuid import uuid4

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import delete, insert, select
from sqlalchemy.engine import Connection
from sqlalchemy.exc import IntegrityError

from ..database import BusinessError, transaction
from .models import AccountView, CreateAccount, Role
from .security import DUMMY_HASH, hash_password, token_hash, verify_password
from .tables import account_audit, accounts, sessions

bearer = HTTPBearer(auto_error=False)
ConnectionDep = Annotated[Connection, Depends(transaction, scope="function")]


def audit(connection, account, actor_id, action):
    connection.execute(
        insert(account_audit).values(
            id=uuid4(),
            account_id=account["id"],
            actor_id=actor_id,
            action=action,
            at=datetime.now(UTC),
            revision=account["revision"],
        )
    )


def create_account(connection, data: CreateAccount, actor_id=None):
    account_id = uuid4()
    values = dict(
        id=account_id,
        username=data.username.lower(),
        display_name=data.display_name,
        role=data.role.value,
        can_maintain=data.can_maintain,
        active=True,
        revision=1,
        password_hash=hash_password(data.password),
    )
    try:
        connection.execute(insert(accounts).values(**values))
    except IntegrityError as error:
        raise BusinessError(409, "username_conflict", "该账号已存在。") from error
    audit(connection, values, actor_id or account_id, "created")
    return AccountView.model_validate(values)


def login(connection, username, password):
    account = (
        connection.execute(
            select(accounts).where(accounts.c.username == username.lower()).with_for_update()
        )
        .mappings()
        .first()
    )
    valid = verify_password(password, account["password_hash"] if account else DUMMY_HASH)
    if not account or not valid or not account["active"]:
        raise BusinessError(401, "invalid_credentials", "账号或密码不正确，或账号已停用。")
    token = secrets.token_urlsafe(32)
    expires = datetime.now(UTC) + timedelta(hours=12)
    connection.execute(
        insert(sessions).values(
            token_hash=token_hash(token),
            account_id=account["id"],
            expires_at=expires,
        )
    )
    return dict(access_token=token, expires_at=expires, account=AccountView.model_validate(account))


def authenticated(
    connection: ConnectionDep,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
) -> AccountView:
    if credentials and credentials.scheme.lower() == "bearer":
        # Share-lock the account for this transaction: disabling/resetting an account
        # waits for existing operations and no new operation can use the old session.
        row = (
            connection.execute(
                select(accounts)
                .join(sessions, accounts.c.id == sessions.c.account_id)
                .where(
                    sessions.c.token_hash == token_hash(credentials.credentials),
                    sessions.c.expires_at > datetime.now(UTC),
                    accounts.c.active.is_(True),
                )
                .with_for_update(read=True, of=accounts)
            )
            .mappings()
            .first()
        )
        if row:
            return AccountView.model_validate(row)
    raise BusinessError(401, "session_expired", "登录已失效，请重新登录。")


AccountDep = Annotated[AccountView, Depends(authenticated)]


def require_maintain(account: AccountView):
    if account.role == Role.staff and not account.can_maintain:
        raise BusinessError(403, "permission_denied", "当前账号未获维护资料与处方的权限。")


def require_admin(account: AccountView):
    if account.role != Role.admin:
        raise BusinessError(403, "permission_denied", "此操作需要管理员权限。")


def revoke_sessions(connection, account_id):
    connection.execute(delete(sessions).where(sessions.c.account_id == account_id))
