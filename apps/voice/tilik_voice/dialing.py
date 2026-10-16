"""Pagar nomor tujuan panggilan keluar. Dicek sebelum setiap panggilan Twilio dibuat."""

from __future__ import annotations

import re

from . import config

# Nomor darurat Indonesia + 112 internasional. Tidak pernah ditelepon oleh server ini, DEMO_MODE atau bukan.
EMERGENCY_NUMBERS = {"110", "112", "113", "115", "118", "119", "129"}

E164 = re.compile(r"^\+[1-9]\d{7,14}$")


class DialBlocked(ValueError):
    pass


def check_destination(number: str, *, demo_mode: bool | None = None, allowlist: set[str] | None = None) -> str:
    """Kembalikan nomor E.164 yang boleh ditelepon, atau lempar DialBlocked."""
    demo_mode = config.DEMO_MODE if demo_mode is None else demo_mode
    allowlist = config.DEMO_ALLOWLIST if allowlist is None else allowlist
    n = re.sub(r"[\s\-()]", "", number or "")
    digits = n.lstrip("+")
    if digits in EMERGENCY_NUMBERS or digits.removeprefix("62") in EMERGENCY_NUMBERS:
        raise DialBlocked("Nomor darurat tidak pernah ditelepon oleh TILIK")
    if not E164.match(n):
        raise DialBlocked("Nomor harus format E.164, contoh +6281234567890")
    if demo_mode and n not in allowlist:
        raise DialBlocked("DEMO_MODE: nomor tidak ada di DEMO_ALLOWLIST")
    return n
