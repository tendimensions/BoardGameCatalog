FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y gcc && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN mkdir -p /app/data /app/logs

ENV DJANGO_SETTINGS_MODULE=boardgame_catalog.settings
# Placeholder only — real SECRET_KEY comes from .env at runtime
ENV SECRET_KEY=build-time-placeholder-not-used-at-runtime

RUN python manage.py collectstatic --noinput

EXPOSE 8000

CMD ["gunicorn", \
     "--bind", "0.0.0.0:8000", \
     "--workers", "3", \
     "--timeout", "60", \
     "--access-logfile", "-", \
     "--error-logfile", "-", \
     "boardgame_catalog.wsgi:application"]
