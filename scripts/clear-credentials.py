#!/usr/bin/env python3
"""Remove saved AI Game Publisher credentials."""

from pathlib import Path

CONFIG_FILE = Path.home() / ".publisher" / "config.json"

if CONFIG_FILE.exists():
    CONFIG_FILE.unlink()
    print(f"已删除: {CONFIG_FILE}")
else:
    print(f"配置不存在: {CONFIG_FILE}")
