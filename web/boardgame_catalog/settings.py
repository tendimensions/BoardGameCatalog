import os
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = os.environ.get('SECRET_KEY', 'django-insecure-dev-key-change-in-production')

ENV = os.environ.get('ENV', 'development')
DEBUG = ENV != 'production'

ALLOWED_HOSTS = os.environ.get(
    'ALLOWED_HOSTS',
    'boardgames.tendimensions.com,localhost,127.0.0.1'
).split(',')

# Required in Django 4.0+ when requests arrive via a proxy (Cloudflare).
# Must include the scheme; comma-separated list in the env var.
CSRF_TRUSTED_ORIGINS = os.environ.get(
    'CSRF_TRUSTED_ORIGINS',
    'https://boardgames.tendimensions.com'
).split(',')

# Full URL used when constructing links in emails
SITE_URL = os.environ.get('SITE_URL', 'http://localhost:8000')

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'accounts',
    'catalog',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'boardgame_catalog.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
                'boardgame_catalog.context_processors.app_version',
            ],
        },
    },
]

WSGI_APPLICATION = 'boardgame_catalog.wsgi.application'

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': os.environ.get('DB_PATH') or str(BASE_DIR / 'db.sqlite3'),
    }
}

AUTH_USER_MODEL = 'accounts.User'

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
        'OPTIONS': {'min_length': 8},
    },
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
]

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

STATIC_URL = '/static/'
STATICFILES_DIRS = [BASE_DIR / 'static']
STATIC_ROOT = BASE_DIR / 'staticfiles'

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

LOGIN_URL = '/accounts/login/'
LOGIN_REDIRECT_URL = '/collection/'
LOGOUT_REDIRECT_URL = '/accounts/login/'

# ── Email ──────────────────────────────────────────────────────────────────────
# Development prints emails to the console.
# Production sends via Microsoft Graph API (client credentials flow).
if DEBUG:
    EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'
else:
    EMAIL_BACKEND = 'accounts.graph_email_backend.GraphEmailBackend'

# Microsoft Graph — required in production; unused in development.
# Set these in ~/boardgames/.env on the server.
MS_GRAPH_TENANT_ID = os.environ.get('MS_GRAPH_TENANT_ID', '')
MS_GRAPH_CLIENT_ID = os.environ.get('MS_GRAPH_CLIENT_ID', '')
MS_GRAPH_CLIENT_SECRET = os.environ.get('MS_GRAPH_CLIENT_SECRET', '')
MS_GRAPH_SENDER = os.environ.get('MS_GRAPH_SENDER', 'noreply@tendimensions.com')

# ── External APIs ──────────────────────────────────────────────────────────────
# BGG XML API v2 — bearer token required as of 2025.
# Register at: https://boardgamegeek.com/using_the_xml_api
BGG_API_TOKEN = os.environ.get('BGG_API_TOKEN', '')
GAMEUPC_API_KEY = os.environ.get('GAMEUPC_API_KEY', '')

DEFAULT_FROM_EMAIL = MS_GRAPH_SENDER

# ── Django REST Framework ──────────────────────────────────────────────────────
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'accounts.authentication.APIKeyAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
    'DEFAULT_RENDERER_CLASSES': [
        'rest_framework.renderers.JSONRenderer',
    ],
}

# ── Session ────────────────────────────────────────────────────────────────────
SESSION_COOKIE_AGE = 60 * 60 * 24 * 14  # 2 weeks

# ── Production security headers ────────────────────────────────────────────────
if not DEBUG:
    # SSL is terminated by Cloudflare, not by this server.
    # nginx hardcodes X-Forwarded-Proto: https so Django treats requests as
    # secure without needing to redirect HTTP→HTTPS itself (Cloudflare already
    # enforces HTTPS at the edge; redirecting here would cause a loop).
    SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
    SECURE_SSL_REDIRECT = False
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SECURE_CONTENT_TYPE_NOSNIFF = True
    X_FRAME_OPTIONS = 'DENY'
