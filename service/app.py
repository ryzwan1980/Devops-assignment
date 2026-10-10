
import os
from flask import Flask, jsonify

app = Flask(__name__)

@app.get("/")
def index():
    return jsonify({
        "app": os.environ.get("APP_NAME", "devops-assignment"),
        "version": os.environ.get("VERSION", "0.1.0"),
        "pod": os.environ.get("HOSTNAME", "unknown"),
    })

@app.get("/healthz")
def health():
    return jsonify({"status": "ok"}), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
