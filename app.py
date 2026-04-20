import asyncio
from datetime import datetime, timezone

import uvicorn
from fastapi import FastAPI


app = FastAPI(title="Sample Running App")


@app.get("/")
async def read_root() -> dict[str, str]:
    return {"message": "FastAPI server is running"}


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


async def timestamp_worker() -> None:
    while True:
        now = datetime.now(timezone.utc).isoformat()
        print(f"[worker] {now}", flush=True)
        await asyncio.sleep(30)


@app.on_event("startup")
async def start_background_worker() -> None:
    app.state.worker_task = asyncio.create_task(timestamp_worker())


@app.on_event("shutdown")
async def stop_background_worker() -> None:
    worker_task = getattr(app.state, "worker_task", None)
    if worker_task is not None:
        worker_task.cancel()
        try:
            await worker_task
        except asyncio.CancelledError:
            pass


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
