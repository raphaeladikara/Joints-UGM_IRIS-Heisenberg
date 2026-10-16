"""Pemuat konten percakapan (folder `content/` di akar repo = sumber tunggal skrip dan aturan)."""

from __future__ import annotations

import json
import re
from functools import lru_cache
from typing import Any

from . import config


@lru_cache(maxsize=1)
def scripts() -> dict[str, Any]:
    return json.loads((config.CONTENT_DIR / "scripts.json").read_text(encoding="utf-8"))


@lru_cache(maxsize=1)
def red_flags() -> dict[str, Any]:
    data = json.loads((config.CONTENT_DIR / "red_flags.json").read_text(encoding="utf-8"))
    for rule in data["rules"]:
        rule["compiled"] = [re.compile(p) for p in rule["patterns"]]
    return data


def line(key: str, lang: str = "id", **values: Any) -> str:
    """Ambil satu kalimat skrip. Bahasa selain `id` jatuh ke `id` bila kalimatnya belum ada."""
    s = scripts()
    template = s.get(lang, {}).get(key) or s["id"][key]
    return template.format(**values)


def education(index: int) -> str:
    items = scripts()["education"]
    return items[index % len(items)]


def briefing(key: str, **values: Any) -> str:
    return scripts()["briefing"][key].format(**values)


def label(code: str) -> str:
    for rule in red_flags()["rules"]:
        if rule["code"] == code:
            return rule["label"]
    return red_flags()["labels"].get(code, code)
