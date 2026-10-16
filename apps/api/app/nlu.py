"""Pemahaman ucapan berbasis aturan: angka kata (Indonesia + Jawa), tensi, jam, ya/tidak, kepatuhan obat.

Jalur ini deterministik dan tidak butuh API apa pun, sehingga prototype tetap jalan tanpa kunci OpenAI.
LLM (bila dikonfigurasi) hanya menambah lapisan, tidak menggantikan validasi di sini.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Any

from . import config

UNITS = {
    "nol": 0, "kosong": 0,
    "satu": 1, "siji": 1, "setunggal": 1,
    "dua": 2, "loro": 2, "kalih": 2,
    "tiga": 3, "telu": 3, "tigang": 3, "telung": 3,
    "empat": 4, "papat": 4, "sekawan": 4, "patang": 4,
    "lima": 5, "gangsal": 5, "limang": 5,
    "enam": 6, "enem": 6, "nem": 6, "nenem": 6,
    "tujuh": 7, "pitu": 7, "pitung": 7,
    "delapan": 8, "wolu": 8, "wolung": 8,
    "sembilan": 9, "sanga": 9, "songo": 9, "sangang": 9,
}
# Kata yang sudah membawa nilai lengkap.
WHOLE = {
    "sepuluh": 10, "sedasa": 10, "sebelas": 11, "seratus": 100, "satus": 100,
    "seket": 50, "sèket": 50, "sewidak": 60, "selawe": 25, "setengah": None,
}
TENS = {"puluh", "dasa", "doso"}
HUNDREDS = {"ratus", "atus"}
TEEN = {"belas", "welas"}
NUMBER_WORDS = set(UNITS) | set(WHOLE) | TENS | HUNDREDS | TEEN

_TOKEN = re.compile(r"\d+|[a-zèé']+")


def normalize(text: str) -> str:
    t = text.lower()
    t = re.sub(r"[‘’]", "'", t)
    t = re.sub(r"[^\w\s/.:,'-]", " ", t)
    return re.sub(r"\s+", " ", t).strip()


def extract_numbers(text: str) -> list[int]:
    """Ambil semua bilangan (angka atau kata) berurutan. 'seratus lima puluh per sembilan puluh' -> [150, 90]."""
    out: list[int] = []
    total = cur = 0
    in_number = False

    def flush() -> None:
        nonlocal total, cur, in_number
        if in_number:
            out.append(total + cur)
        total = cur = 0
        in_number = False

    for tok in _TOKEN.findall(normalize(text)):
        if tok.isdigit():
            flush()
            out.append(int(tok))
            continue
        if tok in WHOLE and WHOLE[tok] is not None:
            val = WHOLE[tok]
            if val == 100:
                total += cur * 100 if cur else 100
                cur = 0
            elif in_number and cur and cur % 10 == 0 and val < 10:
                cur += val
            elif in_number and cur:
                flush()
                cur = val
            else:
                cur += val
            in_number = True
        elif tok in UNITS:
            u = UNITS[tok]
            if in_number and cur and (cur < 10 or cur % 10 != 0):
                # dua unit berurutan tanpa pengali = dua bilangan terpisah ("enam empat puluh" = 6, 40)
                flush()
            cur += u
            in_number = True
        elif tok in TENS and in_number:
            cur = (cur or 1) * 10
        elif tok in TEEN and in_number:
            cur = cur + 10
        elif tok in HUNDREDS and in_number:
            total += (cur or 1) * 100
            cur = 0
        else:
            flush()
    flush()
    return out


@dataclass
class BloodPressure:
    systolic: int
    diastolic: int


def parse_bp(text: str) -> BloodPressure | None:
    nums = extract_numbers(text)
    bp_cfg = {"valid_systolic": [60, 260], "valid_diastolic": [30, 160]}
    for i in range(len(nums) - 1):
        s, d = nums[i], nums[i + 1]
        if bp_cfg["valid_systolic"][0] <= s <= bp_cfg["valid_systolic"][1] and \
                bp_cfg["valid_diastolic"][0] <= d <= bp_cfg["valid_diastolic"][1] and s > d:
            return BloodPressure(s, d)
    return None


_ONES = ["", "satu", "dua", "tiga", "empat", "lima", "enam", "tujuh", "delapan", "sembilan"]


def terbilang(n: int) -> str:
    """Angka ke kata Indonesia (0-999), untuk konfirmasi ulang tensi secara lisan."""
    if n == 0:
        return "nol"
    parts: list[str] = []
    h, rest = divmod(n, 100)
    if h:
        parts.append("seratus" if h == 1 else f"{_ONES[h]} ratus")
    if rest:
        if rest < 10:
            parts.append(_ONES[rest])
        elif rest == 10:
            parts.append("sepuluh")
        elif rest == 11:
            parts.append("sebelas")
        elif rest < 20:
            parts.append(f"{_ONES[rest - 10]} belas")
        else:
            t, o = divmod(rest, 10)
            parts.append(f"{_ONES[t]} puluh" + (f" {_ONES[o]}" if o else ""))
    return " ".join(parts)


YES_WORDS = r"\b(ya|iya|iyo|yo|nggih|inggih|enggih|ggih|leres|betul|benar|bener|sampun|sudah|udah|wis|uwis|wes|sip|oke|ok|boleh|saya sendiri|kula piyambak|aku dhewe|aku dewe|baik|apik|sae)\b"
NO_WORDS = r"\b(tidak|tak|nggak|ngga|gak|enggak|ndak|mboten|boten|ora|belum|dereng|durung|bukan|salah|keliru|lepat)\b"


def yes_no(text: str) -> bool | None:
    t = normalize(text)
    if re.search(NO_WORDS, t):
        return False
    if re.search(YES_WORDS, t):
        return True
    return None


def adherence(text: str) -> str | None:
    """Kembalikan 'sudah' | 'belum' | None (tidak jelas)."""
    t = normalize(text)
    if re.search(r"obat\w*( (saya|kula|ku))? (sudah |sampun |wis |udah )?(habis|telas|entek)", t) or re.search(r"\b(telas|entek)\b", t):
        return "belum"
    if re.search(r"\b(belum|dereng|durung|lupa|kelalen|supe|tidak|nggak|mboten|ora|ndak|gak)\b", t):
        return "belum"
    if re.search(r"\b(sudah|sampun|wis|uwis|wes|udah|tadi|barusan|minum)\b", t):
        return "sudah"
    return None


def med_reason(text: str) -> str:
    t = normalize(text)
    if re.search(r"\b(habis|telas|entek|kehabisan|ga ada obat|tidak ada obat)\b", t):
        return "out_of_stock"
    if re.search(r"\b(lupa|kelalen|supe|kelupaan)\b", t):
        return "forgot"
    if re.search(r"(efek|mual|gatal|batuk|pusing setelah|pusing habis|bengkak|ga cocok|tidak cocok|mboten cocok|ora cocok)", t):
        return "side_effect"
    if re.search(r"(sehat|sae|baik-baik|ora popo|tidak apa|mboten napa|kuat|tidak terasa|ora krasa|enak)", t):
        return "feel_healthy"
    return "other"


def no_complaint(text: str) -> bool:
    t = normalize(text)
    return bool(re.search(
        r"(tidak ada|nggak ada|ga ada|gak ada|ndak ada|mboten wonten|boten wonten|ora ana|ora ono|sehat|sae|baik|apik|alhamdulillah|aman|biasa saja|tidak|mboten)",
        t,
    ))


def asks_if_ai(text: str) -> bool:
    t = normalize(text)
    return bool(re.search(r"(robot|mesin|manusia|orang beneran|orang asli|tiyang (napa|nopo|menapa)|kamu siapa|sampeyan sinten|panjenengan sinten|ini siapa)", t))


def asks_dosage(text: str) -> bool:
    t = normalize(text)
    return bool(re.search(r"(dosis|berapa (tablet|butir|biji|kali)|boleh (berhenti|stop|ganti|dobel|minum dua)|ganti obat|berhenti minum|sakit apa saya|saya sakit apa|diagnosa)", t))


def mentions_missing_family(text: str) -> bool:
    t = normalize(text)
    return bool(re.search(r"(kangen|rindu|sepi|kesepian|sendirian terus)", t))


# Leksikon suasana hati (Indonesia + Jawa). Sengaja sederhana dan bisa diaudit; bukan diagnosis depresi.
_LONELY = r"\b(kangen|rindu|sepi|kesepian|sendirian|ora ana kanca|ora ono kanca|tidak ada teman|nggak ada teman|ditinggal|jarang (ditelepon|ditelpon|pulang)|ngelangut|nelangsa)\b"
_SAD = r"\b(sedih|susah tidur|susah|sedhih|capek|capai|lelah|kesel|bingung|takut|khawatir|kuatir|was-was|nangis|menangis|males|ora iso turu|tidak bisa tidur|kepikiran|ngenes|loro ati|sakit hati)\b"
_HAPPY = r"\b(senang|seneng|bahagia|gembira|bungah|syukur|alhamdulillah|panen|lega|ketawa|tertawa|asyik|asik|senam|pengajian|arisan|jalan-jalan|dolan|menginap|nginep|wisuda|bertelur|seger)\b"


def mood(text: str) -> dict[str, Any]:
    """Suasana hati dari cerita harian: senang / biasa / sedih + tanda kesepian, beserta kata pemicunya."""
    t = normalize(text)
    lonely = [m.group(0) for m in re.finditer(_LONELY, t)]
    sad = [m.group(0) for m in re.finditer(_SAD, t)]
    happy = [m.group(0) for m in re.finditer(_HAPPY, t)]
    score = len(happy) - len(sad) - (1 if lonely else 0)
    label = "senang" if score > 0 else ("sedih" if score < 0 else "biasa")
    return {"mood": label, "lonely": bool(lonely), "cues": list(dict.fromkeys(lonely + sad + happy))[:4]}


def not_measured(text: str) -> bool:
    t = normalize(text)
    return bool(re.search(r"(belum|dereng|durung|tidak|nggak|mboten|ora|ndak|lupa)\w* (ukur|ngukur|mengukur|nensi|tensi|punya|gadah|duwe)", t)) or \
        bool(re.search(r"\b(belum|dereng|durung|tidak punya|ga punya|mboten gadah|ora duwe)\b", t))


# ---------- jam terakhir normal (last known well) ----------

_PART_OF_DAY_PM = r"(sore|malam|wengi|dalu|siang|awan)"


@dataclass
class TimeParse:
    when: datetime
    approx: bool
    note: str


def _hour_minute_from_words(t: str) -> tuple[int, int] | None:
    m = re.search(r"(\d{1,2})[.:](\d{2})", t)
    if m:
        return int(m.group(1)), int(m.group(2))
    m = re.search(r"setengah (\w+)", t)
    if m:
        nums = extract_numbers(m.group(1))
        if nums and 1 <= nums[0] <= 24:
            return (nums[0] - 1) % 24, 30
    after = re.search(r"(?:jam|pukul|tabuh)\s+(.+)", t)
    segment = after.group(1) if after else t
    nums = extract_numbers(segment)
    if not nums:
        return None
    hour = nums[0]
    if not 0 <= hour <= 24:
        return None
    minute = 0
    if re.search(r"(lewat|liwat) seperempat", segment):
        minute = 15
    elif re.search(r"kurang seperempat", segment):
        hour, minute = hour - 1, 45
    elif len(nums) > 1 and 0 <= nums[1] < 60:
        if re.search(r"kurang", segment):
            hour, minute = hour - 1, 60 - nums[1]
        else:
            minute = nums[1]
    return hour % 24, minute


def parse_time_of_day(text: str, ref: datetime | None = None) -> TimeParse | None:
    """Tafsirkan 'jam enam lewat empat puluh', 'setengah tujuh', '6.40', '30 menit yang lalu', 'tadi subuh'."""
    ref = ref or config.now()
    t = normalize(text)

    m = re.search(r"(\w+(?: \w+)?) (menit|jam) (yang )?(lalu|kepungkur|kapungkur|sing wis)", t)
    if m:
        nums = extract_numbers(m.group(1))
        if nums:
            delta = timedelta(minutes=nums[-1]) if m.group(2) == "menit" else timedelta(hours=nums[-1])
            return TimeParse(ref - delta, approx=True, note=m.group(0))
    if re.search(r"\b(barusan|baru saja|nembe mawon|lagi wae|mau wae)\b", t):
        return TimeParse(ref - timedelta(minutes=10), approx=True, note="barusan")

    hm = _hour_minute_from_words(t) if re.search(r"(jam|pukul|tabuh|setengah|\d)", t) else None
    if hm:
        hour, minute = hm
        if re.search(_PART_OF_DAY_PM, t) and hour < 12:
            hour += 12
        when = ref.replace(hour=hour, minute=minute, second=0, microsecond=0)
        if when > ref + timedelta(minutes=5):
            when -= timedelta(days=1)
        return TimeParse(when, approx=False, note=text.strip())

    if re.search(r"(tadi malam|semalam|sebelum tidur|wingi bengi|dalu wau|mau bengi)", t):
        when = (ref - timedelta(days=1)).replace(hour=21, minute=0, second=0, microsecond=0)
        return TimeParse(when, approx=True, note="sebelum tidur semalam")
    if re.search(r"(subuh|bangun tidur|tangi turu|wungu sare)", t):
        when = ref.replace(hour=5, minute=0, second=0, microsecond=0)
        if when > ref:
            when -= timedelta(days=1)
        return TimeParse(when, approx=True, note="sekitar subuh / bangun tidur")
    return None


def sentence_similarity(said: str, target: str) -> float:
    """Proporsi kata kalimat uji yang terucap (dipakai skrining 'ulangi kalimat')."""
    said_words = set(normalize(said).split())
    target_words = normalize(target).split()
    if not target_words:
        return 0.0
    return sum(1 for w in target_words if w in said_words) / len(target_words)
