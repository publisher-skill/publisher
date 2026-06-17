#!/usr/bin/env python3
"""Read saved credentials, refresh token, and print Authorization header."""

import json
import os
import stat
import urllib.error
import urllib.request
from pathlib import Path

DEFAULT_BASE_URL = "https://ai-pub.pushwebly.com"
CONFIG_DIR = Path.home() / ".publisher"
CONFIG_FILE = CONFIG_DIR / "config.json"


def load_config() -> dict:
    if not CONFIG_FILE.exists():
        raise SystemExit(f"配置不存在: {CONFIG_FILE}\n请先运行 scripts/save-credentials.py 保存用户名和密码。")
    return json.loads(CONFIG_FILE.read_text(encoding="utf-8"))


def request_json(request: urllib.request.Request, error_prefix: str) -> dict:
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            body = response.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise SystemExit(f"{error_prefix} HTTP {exc.code}: {body}") from exc
    except urllib.error.URLError as exc:
        raise SystemExit(f"无法连接服务: {exc}") from exc

    result = json.loads(body)
    if result.get("code") != 0:
        raise SystemExit(f"{error_prefix}: {result.get('message')}")
    return result["data"]


def request_token(base_url: str, username: str, password: str) -> dict:
    payload = json.dumps({"username": username, "password": password}).encode("utf-8")
    request = urllib.request.Request(
        f"{base_url.rstrip('/')}/api/auth/login-or-register",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    return request_json(request, "获取 token 失败")


def verify_authorization(base_url: str, authorization: str) -> dict:
    request = urllib.request.Request(
        f"{base_url.rstrip('/')}/api/auth/verify-token",
        headers={"Authorization": authorization},
        method="GET",
    )
    return request_json(request, "token 校验失败")


def save_config(config: dict) -> None:
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    CONFIG_FILE.write_text(json.dumps(config, ensure_ascii=False, indent=2), encoding="utf-8")
    try:
        os.chmod(CONFIG_FILE, stat.S_IRUSR | stat.S_IWUSR)
    except OSError:
        pass


def main() -> None:
    config = load_config()
    base_url = config.get("baseUrl") or os.environ.get("AI_GAME_BASE_URL") or DEFAULT_BASE_URL
    username = config.get("username")
    password = config.get("password")

    if username and password:
        data = request_token(base_url, username, password)
        config["baseUrl"] = base_url.rstrip("/")
        config["authorization"] = f"Bearer {data['token']}"
        config["userId"] = data.get("userId")
        save_config(config)
    elif config.get("authorization"):
        verify_authorization(base_url, config["authorization"])

    authorization = config.get("authorization")
    if not authorization:
        raise SystemExit("配置中没有 authorization，也没有 username/password 可自动获取 token。")
    print(authorization)


if __name__ == "__main__":
    main()
