"""Jalur LLM opsional (OpenAI Chat Completions lewat HTTP, tanpa SDK).

Tanpa OPENAI_API_KEY semua fungsi mengembalikan None dan sistem tetap berjalan dengan jalur aturan saja.
LLM tidak pernah bisa menurunkan level yang dipicu aturan (OR-gate di safety.py).
"""

from __future__ import annotations

import json
import logging
from typing import Any

import httpx

from . import config

log = logging.getLogger("tilik.llm")

CLASSIFIER_PROMPT = """Kamu adalah pengklasifikasi tanda bahaya untuk layanan telepon lansia hipertensi (draf, bukan diagnosis).
Baca percakapan dan observasi. Kembalikan JSON saja:
{"level": "green|yellow|red", "reasons": [{"code": "KODE_SINGKAT", "quote": "kutipan ucapan pasien"}], "confidence": 0-1}
red = tanda stroke mendadak (wajah mencong, lemah/kebas sesisi, bicara pelo, gangguan lihat mendadak, sakit kepala hebat mendadak,
sempoyongan), nyeri dada, sesak berat, pingsan. yellow = perlu tindak lanjut puskesmas hari ini (obat habis, tensi sangat tinggi tanpa
gejala, bingung, efek samping). green = lainnya. Utamakan recall. Jangan menebak di luar teks."""

EXTRACT_PROMPT = """Dari cerita lansia berikut, ambil 0-2 fakta personal yang hangat untuk diingat dan dijadikan bahan obrolan keluarga.
Kembalikan JSON saja: {"facts": ["kalimat pendek orang ketiga, mis. 'Tomat di kebun hampir panen'"]}. Jangan ambil data medis."""


def _chat_json(system: str, user: str) -> dict[str, Any] | None:
    if not config.llm_enabled():
        return None
    try:
        resp = httpx.post(
            f"{config.OPENAI_BASE_URL}/chat/completions",
            headers={"Authorization": f"Bearer {config.OPENAI_API_KEY}"},
            json={
                "model": config.OPENAI_MODEL_CLASSIFIER,
                "messages": [{"role": "system", "content": system}, {"role": "user", "content": user}],
                "response_format": {"type": "json_object"},
            },
            timeout=config.LLM_TIMEOUT_S,
        )
        resp.raise_for_status()
        return json.loads(resp.json()["choices"][0]["message"]["content"])
    except Exception as exc:  # jalur LLM tidak boleh menjatuhkan panggilan
        log.warning("LLM gagal, lanjut dengan jalur aturan: %s", exc)
        return None


def classify(transcript: list[dict[str, str]], observations: list[dict[str, Any]]) -> dict[str, Any] | None:
    lines = "\n".join(f"{t['speaker']}: {t['text']}" for t in transcript[-12:])
    data = _chat_json(CLASSIFIER_PROMPT, f"Percakapan:\n{lines}\n\nObservasi:\n{json.dumps(observations, ensure_ascii=False)}")
    if not data or data.get("level") not in {"green", "yellow", "red"}:
        return None
    return data


def extract_facts(story: str) -> list[str] | None:
    data = _chat_json(EXTRACT_PROMPT, story)
    if not data or not isinstance(data.get("facts"), list):
        return None
    return [str(f)[:140] for f in data["facts"][:2] if str(f).strip()]
