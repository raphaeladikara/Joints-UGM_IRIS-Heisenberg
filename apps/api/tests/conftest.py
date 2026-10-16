import os
import sys
import tempfile
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
os.environ["TILIK_DB_PATH"] = str(Path(tempfile.mkdtemp()) / "test.db")
os.environ["OPENAI_API_KEY"] = ""  # tes selalu jalur aturan saja

from fastapi.testclient import TestClient  # noqa: E402

from app import main, seed  # noqa: E402


@pytest.fixture()
def client():
    seed.run()
    with TestClient(main.app) as c:
        yield c
