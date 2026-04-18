import json
import os
import shlex
import sys
from pathlib import Path

CONFIG_FILE = Path(__file__).with_name("celery_config.json")
ENV_BY_CONFIG_KEY = {
    "celery_app": "CELERY_APP",
    "broker_url": "CELERY_BROKER_URL",
    "result_backend": "CELERY_RESULT_BACKEND",
    "loglevel": "CELERY_LOGLEVEL",
    "pool": "CELERY_POOL",
    "concurrency": "CELERY_CONCURRENCY",
    "queues": "CELERY_QUEUES",
    "extra_args": "CELERY_EXTRA_ARGS",
    "imports": "CELERY_IMPORTS",
}


def normalize_config_value(config_key: str, value: object) -> str | None:
    if value is None:
        return None

    if config_key == "imports":
        if isinstance(value, list):
            modules = [item.strip() for item in value if isinstance(item, str) and item.strip()]
            return ",".join(modules) if modules else None
        if isinstance(value, str):
            cleaned = value.strip()
            return cleaned or None
        return None

    cleaned = str(value).strip()
    return cleaned or None


def load_config_env() -> dict[str, str]:
    if not CONFIG_FILE.exists():
        return {}

    try:
        config = json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
    except Exception as exc:
        print(f"[celery_worker] WARN: failed to parse {CONFIG_FILE.name}: {exc}")
        return {}

    if not isinstance(config, dict):
        print(f"[celery_worker] WARN: {CONFIG_FILE.name} must be a JSON object")
        return {}

    env_values: dict[str, str] = {}
    for config_key, env_name in ENV_BY_CONFIG_KEY.items():
        normalized = normalize_config_value(config_key, config.get(config_key))
        if normalized:
            env_values[env_name] = normalized

    return env_values


def apply_config_defaults() -> None:
    config_env = load_config_env()
    for env_name, value in config_env.items():
        current = os.getenv(env_name)
        if current is None or not current.strip():
            os.environ[env_name] = value

    if not os.getenv("CELERY_APP"):
        os.environ["CELERY_APP"] = "celery_app:celery"


def build_worker_command() -> list[str]:
    apply_config_defaults()
    worker_id = os.getenv("WORKER_ID", "worker_0")
    celery_app = os.getenv("CELERY_APP")

    if not celery_app:
        print("ERROR: CELERY_APP is required (example: myapp.celery_app:celery)")
        sys.exit(1)

    loglevel = os.getenv("CELERY_LOGLEVEL", "info")
    pool = os.getenv("CELERY_POOL", "solo" if os.name == "nt" else "prefork")
    hostname = os.getenv("CELERY_HOSTNAME", f"{worker_id}@%h")

    command = [
        sys.executable,
        "-m",
        "celery",
        "-A",
        celery_app,
        "worker",
        "--loglevel",
        loglevel,
        "--pool",
        pool,
        "--hostname",
        hostname,
    ]

    concurrency = os.getenv("CELERY_CONCURRENCY")
    if concurrency:
        command.extend(["--concurrency", concurrency])

    queues = os.getenv("CELERY_QUEUES")
    if queues:
        command.extend(["--queues", queues])

    extra_args = os.getenv("CELERY_EXTRA_ARGS", "").strip()
    if extra_args:
        command.extend(shlex.split(extra_args, posix=(os.name != "nt")))

    return command


def main() -> None:
    worker_id = os.getenv("WORKER_ID", "worker_0")
    command = build_worker_command()
    print(f"[{worker_id}] starting celery worker")
    os.execve(sys.executable, command, os.environ.copy())


if __name__ == "__main__":
    main()
