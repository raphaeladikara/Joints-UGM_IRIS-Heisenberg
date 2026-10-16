"""Safety Agent: jalur aturan (sinkron) OR jalur LLM. Level akhir = level tertinggi (dioptimalkan untuk recall)."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from . import content, nlu

LEVEL_RANK = {"green": 0, "yellow": 1, "red": 2}


def max_level(*levels: str | None) -> str:
    best = "green"
    for lv in levels:
        if lv and LEVEL_RANK[lv] > LEVEL_RANK[best]:
            best = lv
    return best


@dataclass
class Finding:
    code: str
    level: str
    action: str
    quote: str
    path: str = "rule"

    def as_reason(self) -> dict[str, Any]:
        return {"path": self.path, "code": self.code, "label": content.label(self.code), "quote": self.quote}


@dataclass
class Assessment:
    findings: list[Finding] = field(default_factory=list)

    @property
    def level(self) -> str:
        return max_level(*(f.level for f in self.findings))

    @property
    def red(self) -> list[Finding]:
        return [f for f in self.findings if f.level == "red"]

    def needs_stroke_screen(self) -> bool:
        return any(f.action == "stroke_screen" for f in self.red)


def _negated(text: str, start: int, negations: list[str]) -> bool:
    window = text[max(0, start - 18):start].split()
    return any(w in negations for w in window[-3:])


def scan_text(text: str) -> Assessment:
    """Jalur 1: pola kata kunci/gejala (Indonesia + Jawa) dengan penanganan negasi sederhana."""
    rf = content.red_flags()
    t = nlu.normalize(text)
    out = Assessment()
    for rule in rf["rules"]:
        for pat in rule["compiled"]:
            m = pat.search(t)
            if m and not _negated(t, m.start(), rf["negations"]):
                out.findings.append(Finding(rule["code"], rule["level"], rule["action"], text.strip()))
                break
    return out


def assess_bp(systolic: int, diastolic: int, symptom_codes: set[str], quote: str) -> Finding | None:
    cfg = content.red_flags()["bp"]
    crisis = systolic >= cfg["crisis_systolic"] or diastolic >= cfg["crisis_diastolic"]
    crisis_symptoms = {"SEVERE_HEADACHE", "CHEST_PAIN", "SEVERE_DYSPNEA", "STROKE_VISION", "CONFUSION"}
    if crisis and symptom_codes & crisis_symptoms:
        return Finding("BP_CRISIS_SYMPTOMATIC", "red", "escalate", quote)
    if crisis:
        return Finding("BP_CRISIS_ASYMPTOMATIC", "yellow", "follow_up", quote)
    if systolic < cfg["low_systolic"] and "MILD_SYMPTOM" in symptom_codes:
        return Finding("BP_LOW_SYMPTOMATIC", "yellow", "follow_up", quote)
    return None


def is_high(systolic: int, diastolic: int) -> bool:
    cfg = content.red_flags()["bp"]
    return systolic >= cfg["high_systolic"] or diastolic >= cfg["high_diastolic"]


def from_llm(result: dict[str, Any] | None) -> list[Finding]:
    """Jalur 2: hasil klasifikasi LLM diubah menjadi temuan. Hanya level kuning/merah yang berpengaruh."""
    if not result or result.get("level") == "green":
        return []
    level = result["level"]
    reasons = result.get("reasons") or [{"code": "LLM_CLASSIFIER", "quote": ""}]
    action = "stroke_screen" if level == "red" else "follow_up"
    return [Finding(str(r.get("code") or "LLM_CLASSIFIER")[:40], level, action, str(r.get("quote") or "")[:200], path="llm") for r in reasons[:3]]
