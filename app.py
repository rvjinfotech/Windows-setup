import asyncio
from datetime import datetime, timezone
import os
import uvicorn
from fastapi import FastAPI


app = FastAPI(title="Sample Running App")


@app.get("/")
async def read_root() -> dict[str, str]:
    port = os.getenv("PORT", 8000)
    return {"message": f"FastAPI server is running fine on port {port}!"}


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
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
