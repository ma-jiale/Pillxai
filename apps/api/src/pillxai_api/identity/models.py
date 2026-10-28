from datetime import datetime
from enum import StrEnum
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, StringConstraints

Name = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=80)]
Username = Annotated[
    str, StringConstraints(strip_whitespace=True, pattern=r"^[a-zA-Z0-9_.-]{3,64}$")
]
Password = Annotated[str, Field(min_length=12, max_length=128)]


class Input(BaseModel):
    model_config = ConfigDict(extra="forbid")


class Role(StrEnum):
    admin = "admin"
    staff = "staff"


class Login(Input):
    username: Username
    password: Annotated[str, Field(min_length=1, max_length=128)]


class AccountView(BaseModel):
    id: UUID
    username: str
    display_name: str
    role: Role
    can_maintain: bool
    active: bool
    revision: int


class LoginResult(BaseModel):
    access_token: str
    expires_at: datetime
    account: AccountView


class CreateAccount(Input):
    username: Username
    display_name: Name
    password: Password
    role: Role = Role.staff
    can_maintain: bool = False


class UpdateAccount(Input):
    expected_revision: Annotated[int, Field(strict=True, ge=1)]
    display_name: Name
    active: bool
    can_maintain: bool


class ResetPassword(Input):
    password: Password


class ChangePassword(ResetPassword):
    current_password: Annotated[str, Field(min_length=1, max_length=128)]


class ActionResult(BaseModel):
    status: str = "ok"
