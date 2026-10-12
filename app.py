import os
from flask import Flask

APP_NAME = os.getenv("APP_NAME", "Default App")
APP_ENV = os.getenv("APP_ENV", "development")
APP_PORT = int(os.getenv("APP_PORT", "5000"))

app = Flask(__name__)

@app.route("/")
def home():
    return f"{APP_NAME} ({APP_ENV})"

@app.route("/health")
def health():
    return {"status": "ok"}

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=APP_PORT)