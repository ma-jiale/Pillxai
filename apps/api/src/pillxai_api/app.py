from contextlib import asynccontextmanager
from uuid import UUID

from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError

from .app_settings import router as settings_router
from .config import Settings
from .contracts import ApiError, Health, SaveContractSample, SavedContractSample
from .database import BusinessError
from .identity.routes import router as identity_router
from .login_limit import LoginLimit
from .planning.routes import router as planning_router
from .prescriptions.routes import router as prescriptions_router
from .releases import router as releases_router
from .residents.routes import router as residents_router
from .storage import RevisionConflict, read_sample, save_sample
from .tasks.routes import router as tasks_router

SCHEMA_REVISION = "20261027_resident_avatar"


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or Settings.from_environment()
    engine = create_engine(
        settings.database_url, pool_pre_ping=True, connect_args={"connect_timeout": 5},
    )

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        yield
        engine.dispose()

    app = FastAPI(
        title="Pillxai API", version="0.1.0", lifespan=lifespan,
        root_path=settings.root_path,
    )
    app.state.engine = engine
    app.state.client_releases_directory = settings.client_releases_directory
    if settings.login_limit_per_minute > 0:
        app.add_middleware(LoginLimit, limit=settings.login_limit_per_minute)
    if settings.enable_contract_probe:
        # Development web preview only. No wildcard origins or cookie credentials.
        app.add_middleware(
            CORSMiddleware,
            allow_origins=["http://localhost:5180", "http://127.0.0.1:5180"],
            allow_methods=["GET", "POST", "PUT"],
            allow_headers=["Authorization", "Content-Type"],
        )
    app.include_router(identity_router)
    app.include_router(settings_router)
    app.include_router(planning_router)
    app.include_router(residents_router)
    app.include_router(prescriptions_router)
    app.include_router(tasks_router)
    app.include_router(releases_router)

    @app.exception_handler(BusinessError)
    async def business_error(request, exception):
        return JSONResponse(
            status_code=exception.status,
            content=ApiError(
                code=exception.code,
                message=exception.message,
            ).model_dump(),
        )

    @app.exception_handler(RequestValidationError)
    async def validation_error(request, exception):
        # Don't echo arbitrary submitted data or internal exception representations.
        messages = {
            "至少填写一个时段的正用量。",
            "半片仅支持每次 0.5 片，由人工预切。",
            "整片或整粒每次须为 0–255 的整数。",
            "结束日期不能早于开始日期。",
        }
        message = "输入不符合要求，请核对必填项、字段长度、日期和用量。"
        for error in exception.errors():
            reason = str(error.get("ctx", {}).get("error", ""))
            if reason in messages:
                message = reason
                break
            if "doses" in error["loc"]:
                message = "用量须为非负整数字符串；半片仅支持 0 或 0.5 片。"
        return JSONResponse(
            status_code=422,
            content=ApiError(
                code="invalid_request", message=message
            ).model_dump(),
        )

    @app.get("/health/live", operation_id="get_liveness", response_model=Health)
    def live():
        return Health(status="ok", service_version=settings.service_version)

    @app.get(
        "/health/ready",
        operation_id="get_readiness",
        response_model=Health,
        responses={503: {"model": ApiError}},
    )
    def ready():
        try:
            with engine.connect() as connection:
                revision = connection.execute(
                    text("SELECT version_num FROM alembic_version")
                ).scalar()
            if revision == SCHEMA_REVISION:
                return Health(status="ready", service_version=settings.service_version)
        except SQLAlchemyError:
            pass
        return JSONResponse(
            status_code=503,
            content=ApiError(
                code="database_unready", message="Database migration required"
            ).model_dump(),
        )

    if settings.enable_contract_probe:

        @app.post(
            "/dev/contract-samples",
            tags=["contract"],
            operation_id="save_contract_sample",
            response_model=SavedContractSample,
            responses={409: {"model": ApiError}, 422: {"model": ApiError}},
        )
        def save(request: SaveContractSample):
            try:
                return save_sample(engine, request)
            except RevisionConflict:
                return JSONResponse(
                    status_code=409,
                    content=ApiError(
                        code="revision_conflict", message="Refresh before saving"
                    ).model_dump(),
                )

        @app.get(
            "/dev/contract-samples/{sample_id}",
            tags=["contract"],
            operation_id="get_contract_sample",
            response_model=SavedContractSample,
            responses={404: {"model": ApiError}, 422: {"model": ApiError}},
        )
        def get(sample_id: UUID):
            result = read_sample(engine, sample_id)
            if result is not None:
                return result
            return JSONResponse(
                status_code=404,
                content=ApiError(code="not_found", message="Sample not found").model_dump(),
            )

    return app
