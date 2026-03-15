"""
BoardGameGeek XML API v2 client.

Production note: BGG blocks requests from cloud/data centre IP ranges (Linode,
AWS, etc.).  For production use, the browser fetches the BGG XML directly and
POSTs it to Django via SyncBGGView.  parse_collection_xml() handles that path.

fetch_collection() makes a server-side request and works in local development
where the machine has a residential IP.
"""

import logging
import time
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from typing import Optional

import requests
from django.conf import settings

logger = logging.getLogger(__name__)

_BGG_BASE = 'https://boardgamegeek.com/xmlapi2'
_REQUEST_DELAY = 2.0   # seconds between requests (BGG rate limit)
_RETRY_DELAY   = 5.0   # seconds to wait after a 202 response
_MAX_RETRIES   = 5


@dataclass
class BGGGame:
    bgg_id:         int
    title:          str
    year_published: Optional[int]
    min_players:    Optional[int]
    max_players:    Optional[int]
    playing_time:   Optional[int]
    thumbnail_url:  str
    image_url:      str


class BGGError(Exception):
    """Raised when the BGG API returns an error or cannot be reached."""


def parse_collection_xml(xml_text: str) -> list[BGGGame]:
    """
    Parse BGG collection XML and return a list of owned games.

    This is the primary production path — the browser fetches the XML and
    submits it here, avoiding server-side IP blocks.
    """
    try:
        root = ET.fromstring(xml_text)
    except ET.ParseError as exc:
        raise BGGError(f'Invalid collection data received: {exc}') from exc

    if root.tag == 'errors':
        message = root.findtext('.//message', default='Unknown error from BoardGameGeek')
        raise BGGError(f'BoardGameGeek error: {message}')

    games = []
    for item in root.findall('item'):
        status = item.find('status')
        if status is None or status.get('own') != '1':
            continue

        bgg_id = int(item.get('objectid'))

        name_el = item.find('name')
        title = (name_el.text or 'Unknown').strip() if name_el is not None else 'Unknown'

        year_el = item.find('yearpublished')
        year = _int_or_none(year_el.text) if year_el is not None else None

        thumbnail_url = _fix_url(item.findtext('thumbnail', default=''))
        image_url     = _fix_url(item.findtext('image', default=''))

        stats = item.find('stats')
        min_players = max_players = playing_time = None
        if stats is not None:
            min_players  = _int_or_none(stats.get('minplayers'))
            max_players  = _int_or_none(stats.get('maxplayers'))
            playing_time = _int_or_none(stats.get('playingtime'))

        games.append(BGGGame(
            bgg_id=bgg_id,
            title=title,
            year_published=year,
            min_players=min_players,
            max_players=max_players,
            playing_time=playing_time,
            thumbnail_url=thumbnail_url,
            image_url=image_url,
        ))

    return games


def fetch_collection(username: str) -> list[BGGGame]:
    """
    Fetch and parse a user's owned collection directly from BGG.

    Works in local development (residential IP).  Blocked by BGG on cloud
    servers — use the browser-side fetch path in production instead.
    """
    url = f'{_BGG_BASE}/collection'
    params = {
        'username': username,
        'excludesubtype': 'boardgameexpansion',
        'stats': 1,
    }
    headers = {
        'User-Agent': 'BoardGameCatalog/1.0 (https://boardgames.tendimensions.com)',
    }
    token = getattr(settings, 'BGG_API_TOKEN', '')
    if token and not token.startswith('CHANGE-ME'):
        headers['Authorization'] = f'Bearer {token}'

    response = None
    for attempt in range(_MAX_RETRIES):
        time.sleep(_REQUEST_DELAY)
        try:
            response = requests.get(url, params=params, headers=headers, timeout=30)
        except requests.RequestException as exc:
            raise BGGError(f'Could not reach BoardGameGeek: {exc}') from exc

        logger.info('BGG collection response: HTTP %s for user %s', response.status_code, username)

        if response.status_code == 202:
            if attempt < _MAX_RETRIES - 1:
                logger.info(
                    'BGG returned 202 for %s — retrying in %ss (attempt %d/%d)',
                    username, _RETRY_DELAY, attempt + 1, _MAX_RETRIES,
                )
                time.sleep(_RETRY_DELAY)
                continue
            raise BGGError(
                'BoardGameGeek is still preparing your collection. '
                'Please wait a moment and try again.'
            )

        if response.status_code != 200:
            logger.error('BGG error response body: %s', response.text[:500])
            raise BGGError(
                f'BoardGameGeek returned an unexpected response (HTTP {response.status_code}). '
                'Please try again later.'
            )

        break

    return parse_collection_xml(response.text)


def _fix_url(url: str) -> str:
    url = (url or '').strip()
    if url.startswith('//'):
        return f'https:{url}'
    return url


def _int_or_none(value) -> Optional[int]:
    try:
        v = int(value)
        return v if v > 0 else None
    except (TypeError, ValueError):
        return None
