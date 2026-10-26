from alembic import context
from sqlalchemy import create_engine

from pillxai_api import app_settings, storage  # noqa: F401
from pillxai_api.config import Settings
from pillxai_api.database import metadata
from pillxai_api.identity import tables as identity_tables  # noqa: F401
from pillxai_api.prescriptions import tables as prescription_tables  # noqa: F401
from pillxai_api.residents import tables as resident_tables  # noqa: F401

database_url = Settings.from_environment().database_url
if context.is_offline_mode():
    context.configure(url=database_url, target_metadata=metadata, literal_binds=True)
    with context.begin_transaction():
        context.run_migrations()
else:
    engine = create_engine(database_url)
    with engine.connect() as connection:
        context.configure(connection=connection, target_metadata=metadata)
        with context.begin_transaction():
            context.run_migrations()
    engine.dispose()
