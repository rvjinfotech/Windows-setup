import os
import signal
import sys
import time

worker_id = os.getenv("WORKER_ID", "worker_0")
port = os.getenv("PORT", "5100")


def stop_worker(_signum, _frame):
    print(f"[{worker_id}] stopping")
    sys.exit(0)


signal.signal(signal.SIGTERM, stop_worker)
signal.signal(signal.SIGINT, stop_worker)

print(f"[{worker_id}] test worker started (PORT={port})")

while True:
    print(f"[{worker_id}] heartbeat")
    sys.stdout.flush()
    time.sleep(30)
