import os
from flask import Flask, jsonify

app = Flask(__name__)

SERVICE_NAME = "products"
PORT = int(os.getenv("PORT", 5000))
WORKER_ID = os.getenv("WORKER_ID", f"{SERVICE_NAME}_0")


@app.get("/")
def root():
    return jsonify(
        {
            "status": "ok",
            "service": SERVICE_NAME,
            "worker_id": WORKER_ID,
            "port": PORT,
        }
    )


@app.get("/health")
def health():
    return jsonify({"status": "healthy", "service": SERVICE_NAME}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=PORT)
