"""Panggilan keluar Twilio lewat REST (tanpa SDK Twilio). Autentikasi API Key SID + secret."""

from __future__ import annotations

from typing import Any
from xml.sax.saxutils import quoteattr

import httpx

from . import config

API = "https://api.twilio.com/2010-04-01"


def stream_twiml(ws_url: str, params: dict[str, str]) -> str:
    """TwiML: sambungkan audio panggilan ke WebSocket kita. Saat WebSocket ditutup, panggilan ikut selesai."""
    ps = "".join(f"<Parameter name={quoteattr(k)} value={quoteattr(v)}/>" for k, v in params.items())
    return f"<Response><Connect><Stream url={quoteattr(ws_url)}>{ps}</Stream></Connect></Response>"


async def create_call(to: str, twiml: str, status_callback: str, client: httpx.AsyncClient | None = None) -> dict[str, Any]:
    data = {
        "To": to,
        "From": config.TWILIO_PHONE_NUMBER,
        "Twiml": twiml,
        "Timeout": str(config.TWILIO_RING_TIMEOUT_S),
        "StatusCallback": status_callback,
        "StatusCallbackMethod": "POST",
        "StatusCallbackEvent": "completed",  # hasil akhir: completed / no-answer / busy / failed / canceled
    }
    auth = (config.TWILIO_API_KEY_SID, config.TWILIO_API_KEY_SECRET)
    url = f"{API}/Accounts/{config.TWILIO_ACCOUNT_SID}/Calls.json"
    async with (client or httpx.AsyncClient(timeout=15.0)) as c:
        r = await c.post(url, data=data, auth=auth)
    if r.status_code >= 400:
        # Pesan Twilio (mis. 21219 nomor belum terverifikasi di akun trial) diteruskan apa adanya.
        raise TwilioError(r.status_code, r.json().get("message", r.text) if r.headers.get("content-type", "").startswith("application/json") else r.text)
    return r.json()


class TwilioError(RuntimeError):
    def __init__(self, status: int, message: str):
        super().__init__(f"Twilio {status}: {message}")
        self.status = status
        self.message = message
