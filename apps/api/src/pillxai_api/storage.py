"""M0 development persistence probe. No production business records live here."""

from sqlalchemy import Column, Integer, Table, select, update
from sqlalchemy.dialects.postgresql import JSONB, UUID, insert
from sqlalchemy.engine import Engine

from .contracts import ContractSample, SaveContractSample, SavedContractSample
from .database import metadata

contract_samples = Table(
    "contract_samples",
    metadata,
    Column("sample_id", UUID(as_uuid=True), primary_key=True),
    Column("revision", Integer, nullable=False),
    Column("payload", JSONB, nullable=False),
)


class RevisionConflict(Exception):
    pass


def save_sample(engine: Engine, request: SaveContractSample) -> SavedContractSample:
    """Compare-and-swap is done inside PostgreSQL, including concurrent creation."""
    payload = request.sample.model_dump(mode="json")
    with engine.begin() as connection:
        if request.expected_revision == 0:
            statement = (
                insert(contract_samples)
                .values(sample_id=request.sample.sample_id, revision=1, payload=payload)
                .on_conflict_do_nothing(index_elements=[contract_samples.c.sample_id])
                .returning(contract_samples.c.revision)
            )
        else:
            statement = (
                update(contract_samples)
                .where(
                    contract_samples.c.sample_id == request.sample.sample_id,
                    contract_samples.c.revision == request.expected_revision,
                )
                .values(revision=request.expected_revision + 1, payload=payload)
                .returning(contract_samples.c.revision)
            )
        revision = connection.execute(statement).scalar_one_or_none()
        if revision is None:
            raise RevisionConflict
    return SavedContractSample(revision=revision, sample=request.sample)


def read_sample(engine: Engine, sample_id) -> SavedContractSample | None:
    with engine.connect() as connection:
        row = (
            connection.execute(
                select(contract_samples).where(contract_samples.c.sample_id == sample_id)
            )
            .mappings()
            .one_or_none()
        )
    if row is None:
        return None
    return SavedContractSample(
        revision=row["revision"], sample=ContractSample.model_validate(row["payload"])
    )
