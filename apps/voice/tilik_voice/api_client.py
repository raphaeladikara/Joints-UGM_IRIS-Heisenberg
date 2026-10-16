"""Klien HTTP ke apps/api. Semua keputusan percakapan (state, safety, eskalasi) ada di sana."""

from __future__ import annotations

from typing import Any

import httpx

from . import config


class TilikApi:
    def __init__(self, base_url: str | None = None, client: httpx.AsyncClient | None = None):
        # Timeout longgar: dialog manager bisa memanggil klasifier LLM (maks ±6 s di sisi API).
        self._client = client or httpx.AsyncClient(base_url=base_url or config.TILIK_API_URL, timeout=15.0)

    async def close(self) -> None:
        await self._client.aclose()

    async def _post(self, path: str, json: dict[str, Any] | None = None) -> dict[str, Any]:
        r = await self._client.post(path, json=json)
        r.raise_for_status()
        return r.json()

    async def health(self) -> dict[str, Any]:
        r = await self._client.get("/v1/health")
        r.raise_for_status()
        return r.json()

    async def patients(self) -> list[dict[str, Any]]:
        r = await self._client.get("/v1/patients")
        r.raise_for_status()
        return r.json()

    async def start_call(self, patient_id: str, auto_answer: bool = False) -> dict[str, Any]:
        return await self._post("/v1/calls", {"patient_id": patient_id, "auto_answer": auto_answer})

    async def answer(self, sid: str) -> dict[str, Any]:
        return await self._post(f"/v1/calls/{sid}/answer")

    async def turn(self, sid: str, text: str) -> dict[str, Any]:
        return await self._post(f"/v1/calls/{sid}/turns", {"text": text[:600]})

    async def no_answer(self, sid: str) -> dict[str, Any]:
        return await self._post(f"/v1/calls/{sid}/no-answer")

    async def hangup(self, sid: str) -> dict[str, Any]:
        return await self._post(f"/v1/calls/{sid}/hangup")
