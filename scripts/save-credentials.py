#!/usr/bin/env python3
"""Save AI Game Publisher username/password locally and fetch a token."""

import getpass
import json
import os
import stat
import sys
import urllib.error
import urllib.request
from pathlib import Path

DEFAULT_BASE_URL = "https://ai-pub.pushwebly.com"
CONFIG_DIR = Path.home() / ".publisher"
CONFIG_FILE = CONFIG_DIR / "config.json"


def request_token(base_url: str, username: str, password: str) -> dict:
    payload = json.dumps({"username": username, "password": password}).encode("utf-8")
    request = urllib.request.Request(
        f"{base_url.rstrip('/')}/api/auth/login-or-register",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            body = response.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise SystemExit(f"登录失败 HTTP {exc.code}: {body}") from exc
    except urllib.error.URLError as exc:
        raise SystemExit(f"无法连接服务: {exc}") from exc

    result = json.loads(body)
    if result.get("code") != 0:
        raise SystemExit(f"登录失败: {result.get('message')}")
    return result["data"]


def write_config(config: dict) -> None:
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    CONFIG_FILE.write_text(json.dumps(config, ensure_ascii=False, indent=2), encoding="utf-8")
    try:
        os.chmod(CONFIG_FILE, stat.S_IRUSR | stat.S_IWUSR)
    except OSError:
        # Windows may not support chmod the same way. Best effort only.
        pass


def main() -> None:
    base_url = os.environ.get("AI_GAME_BASE_URL", DEFAULT_BASE_URL).rstrip("/")
    username = sys.argv[1] if len(sys.argv) > 1 else input("用户名: ").strip()
    password = sys.argv[2] if len(sys.argv) > 2 else getpass.getpass("密码: ")

    if not username or not password:
        raise SystemExit("用户名和密码不能为空")

    data = request_token(base_url, username, password)
    token = data["token"]
    config = {
        "baseUrl": base_url,
        "username": username,
        "password": password,
        "authorization": f"Bearer {token}",
        "userId": data.get("userId"),
    }
    write_config(config)
    print(f"已保存到: {CONFIG_FILE}")
    print("authorization 已更新，下次 Skill 可自动读取。")


if __name__ == "__main__":
    main()
