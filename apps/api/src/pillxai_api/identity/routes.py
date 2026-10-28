from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy import delete, select, update

from ..contracts import ApiError
from ..database import BusinessError, conflict, not_found
from .models import (
    AccountView,
    ActionResult,
    ChangePassword,
    CreateAccount,
    Login,
    LoginResult,
    ResetPassword,
    UpdateAccount,
)
from .security import hash_password, token_hash, verify_password
from .service import (
    AccountDep,
    ConnectionDep,
    audit,
    bearer,
    create_account,
    login,
    require_admin,
    revoke_sessions,
)
from .tables import accounts, sessions

router = APIRouter(
    tags=["identity"], responses={code: {"model": ApiError} for code in (401, 403, 404, 409, 422)}
)


@router.post("/auth/login", operation_id="login", response_model=LoginResult)
def sign_in(data: Login, connection: ConnectionDep):
    return login(connection, data.username, data.password)


@router.get("/auth/me", operation_id="get_account", response_model=AccountView)
def me(account: AccountDep):
    return account


@router.post("/auth/logout", operation_id="logout", response_model=ActionResult)
def logout(account: AccountDep, connection: ConnectionDep, credentials=Depends(bearer)):
    connection.execute(
        delete(sessions).where(
            sessions.c.token_hash == token_hash(credentials.credentials),
        )
    )
    return ActionResult()


@router.post("/auth/password", operation_id="change_password", response_model=ActionResult)
def change_password(data: ChangePassword, account: AccountDep, connection: ConnectionDep):
    row = (
        connection.execute(select(accounts).where(accounts.c.id == account.id).with_for_update())
        .mappings()
        .one()
    )
    if not verify_password(data.current_password, row["password_hash"]):
        raise BusinessError(400, "incorrect_password", "原密码不正确。")
    changed = (
        connection.execute(
            update(accounts)
            .where(accounts.c.id == account.id)
            .values(
                password_hash=hash_password(data.password),
                revision=accounts.c.revision + 1,
            )
            .returning(accounts)
        )
        .mappings()
        .one()
    )
    revoke_sessions(connection, account.id)
    audit(connection, changed, account.id, "password_changed")
    return ActionResult()


@router.get(
    "/accounts",
    operation_id="list_staff",
    response_model=list[AccountView],
)
def list_staff(account: AccountDep, connection: ConnectionDep):
    require_admin(account)
    return (
        connection.execute(
            select(accounts)
            .order_by(accounts.c.username)
        )
        .mappings()
        .all()
    )


@router.post(
    "/accounts",
    operation_id="create_staff",
    response_model=AccountView,
)
def create_staff(data: CreateAccount, account: AccountDep, connection: ConnectionDep):
    require_admin(account)
    return create_account(connection, data, account.id)


def managed_account(connection, account, account_id):
    require_admin(account)
    row = (
        connection.execute(
            select(accounts)
            .where(
                accounts.c.id == account_id,
            )
            .with_for_update()
        )
        .mappings()
        .first()
    )
    if not row:
        not_found()
    if row["id"] == account.id:
        raise BusinessError(403, "permission_denied", "请通过本人密码入口管理当前账号。")
    return row


@router.put(
    "/accounts/{account_id}",
    operation_id="update_staff",
    response_model=AccountView,
)
def update_staff(
    account_id: UUID, data: UpdateAccount, account: AccountDep, connection: ConnectionDep
):
    row = managed_account(connection, account, account_id)
    if row["revision"] != data.expected_revision:
        conflict()
    changed = (
        connection.execute(
            update(accounts)
            .where(accounts.c.id == account_id)
            .values(
                **data.model_dump(exclude={"expected_revision"}),
                revision=row["revision"] + 1,
            )
            .returning(accounts)
        )
        .mappings()
        .one()
    )
    if not changed["active"]:
        revoke_sessions(connection, account_id)
    audit(connection, changed, account.id, "updated")
    return changed


@router.post(
    "/accounts/{account_id}/password",
    operation_id="reset_staff_password",
    response_model=ActionResult,
)
def reset_password(
    account_id: UUID, data: ResetPassword, account: AccountDep, connection: ConnectionDep
):
    row = managed_account(connection, account, account_id)
    changed = (
        connection.execute(
            update(accounts)
            .where(accounts.c.id == account_id)
            .values(
                password_hash=hash_password(data.password),
                revision=row["revision"] + 1,
            )
            .returning(accounts)
        )
        .mappings()
        .one()
    )
    revoke_sessions(connection, account_id)
    audit(connection, changed, account.id, "password_reset")
    return ActionResult()
