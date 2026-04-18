import os
import shlex
import sys


def build_worker_command() -> list[str]:
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
