# Server API TILIK. Build dari akar repo supaya folder content/ ikut:
#   docker compose up --build
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 \
    TILIK_DB_PATH=/data/tilik.db TILIK_CONTENT_DIR=/srv/content

WORKDIR /srv/api
COPY apps/api/requirements.txt apps/api/requirements-dev.txt ./
RUN pip install --no-cache-dir -r requirements-dev.txt

COPY content /srv/content
COPY apps/api/app ./app
COPY apps/api/tests ./tests

EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --retries=5 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/v1/health')"
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
