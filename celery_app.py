import os

from celery import Celery


def env_or_default(name: str, default: str) -> str:
    value = os.getenv(name)
    if value is None:
        return default
    cleaned = value.strip()
    return cleaned or default


broker_url = env_or_default("CELERY_BROKER_URL", "redis://127.0.0.1:6379/0")
result_backend = env_or_default("CELERY_RESULT_BACKEND", "redis://127.0.0.1:6379/1")

celery = Celery("universal_worker")
celery.conf.update(
    broker_url=broker_url,
    result_backend=result_backend,
    task_serializer="json",
    result_serializer="json",
    accept_content=["json"],
    timezone=env_or_default("CELERY_TIMEZONE", "UTC"),
    enable_utc=True,
)

imports_value = env_or_default("CELERY_IMPORTS", "")
imports = [module.strip() for module in imports_value.split(",") if module.strip()]
if imports:
    celery.conf.imports = tuple(imports)


@celery.task(name="universal.ping")
def ping() -> str:
    return "pong"

