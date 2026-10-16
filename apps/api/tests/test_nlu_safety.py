from datetime import datetime

import pytest

from app import config, nlu, safety


@pytest.mark.parametrize("text,expected", [
    ("seratus lima puluh per sembilan puluh", (150, 90)),
    ("150/90", (150, 90)),
    ("tadi 145 per 88 Mbak", (145, 88)),
    ("satus seket per sangang dasa", (150, 90)),
    ("seratus delapan puluh empat per seratus empat", (184, 104)),
])
def test_parse_bp(text, expected):
    bp = nlu.parse_bp(text)
    assert bp and (bp.systolic, bp.diastolic) == expected


def test_parse_bp_rejects_nonsense():
    assert nlu.parse_bp("umur saya tujuh puluh dua") is None


def test_terbilang():
    assert nlu.terbilang(150) == "seratus lima puluh"
    assert nlu.terbilang(184) == "seratus delapan puluh empat"
    assert nlu.terbilang(90) == "sembilan puluh"
    assert nlu.terbilang(112) == "seratus dua belas"


@pytest.mark.parametrize("text,hm", [
    ("jam enam lewat empat puluh", (6, 40)),
    ("sekitar jam setengah tujuh", (6, 30)),
    ("jam 6.40 tadi", (6, 40)),
    ("jam tujuh kurang seperempat", (6, 45)),
    ("tadi jam enem", (6, 0)),
])
def test_parse_time(text, hm):
    ref = datetime(2026, 10, 18, 7, 30, tzinfo=config.WIB)
    t = nlu.parse_time_of_day(text, ref)
    assert t and (t.when.hour, t.when.minute) == hm


def test_parse_time_relative():
    ref = datetime(2026, 10, 18, 7, 30, tzinfo=config.WIB)
    t = nlu.parse_time_of_day("kira-kira tiga puluh menit yang lalu", ref)
    assert t and (t.when.hour, t.when.minute) == (7, 0)


@pytest.mark.parametrize("text,status", [
    ("sudah, tadi habis sarapan", "sudah"),
    ("sampun", "sudah"),
    ("belum, lupa", "belum"),
    ("obatnya sudah habis", "belum"),
])
def test_adherence(text, status):
    assert nlu.adherence(text) == status


@pytest.mark.parametrize("text,code", [
    ("ngomongku kok angel, tangan kiwa lemes", "STROKE_SPEECH"),
    ("tangan kiri saya lemas sekali", "STROKE_MOTOR"),
    ("mulut saya kok mencong", "STROKE_FACE"),
    ("dada saya nyeri seperti ditindih", "CHEST_PAIN"),
    ("kepala saya sakit sekali, belum pernah begini", "SEVERE_HEADACHE"),
    ("tadi pagi saya pingsan di dapur", "SYNCOPE_FALL"),
])
def test_red_flags(text, code):
    a = safety.scan_text(text)
    assert code in {f.code for f in a.red}


@pytest.mark.parametrize("text", [
    "tidak ada keluhan, sehat",
    "tidak pusing, tidak nyeri dada",
    "mboten wonten napa-napa",
    "saya takut kena stroke seperti tetangga",
])
def test_no_false_red(text):
    assert safety.scan_text(text).level != "red"


def test_bp_crisis_rules():
    assert safety.assess_bp(184, 104, set(), "").level == "yellow"
    assert safety.assess_bp(190, 110, {"SEVERE_HEADACHE"}, "").level == "red"
    assert safety.assess_bp(140, 90, set(), "") is None
