"""
BoardGameGeek XML API v2 client.

fetch_collection() performs a server-side request to BGG using the registered
BGG_API_TOKEN (set in .env).  The token identifies the application to BGG and
is required for all API access.  parse_collection_xml() is retained as a
utility for testing with pre-fetched XML.
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
    headers = _bgg_headers()

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


def _bgg_headers() -> dict:
    """Common headers for all BGG API requests, including auth token when configured."""
    headers = {
        'User-Agent': 'BoardGameCatalog/1.0 (https://boardgames.tendimensions.com)',
    }
    token = getattr(settings, 'BGG_API_TOKEN', '')
    if token and not token.startswith('CHANGE-ME'):
        headers['Authorization'] = f'Bearer {token}'
    return headers


def fetch_thing(bgg_id: int) -> BGGGame:
    """
    Fetch a single board game's metadata from BGG by its ID.

    Used by scan confirm and link flows when the game is not yet in our DB.
    Raises BGGError on network or API errors, or if the game is not found.
    """
    url = f'{_BGG_BASE}/thing'
    params = {'id': bgg_id, 'type': 'boardgame'}
    headers = _bgg_headers()

    resp = None
    for attempt in range(_MAX_RETRIES):
        time.sleep(_REQUEST_DELAY)
        try:
            resp = requests.get(url, params=params, headers=headers, timeout=30)
        except requests.RequestException as exc:
            raise BGGError(f'Could not reach BoardGameGeek: {exc}') from exc

        if resp.status_code == 202:
            if attempt < _MAX_RETRIES - 1:
                logger.info('BGG returned 202 for thing %s — retrying (%d/%d)', bgg_id, attempt + 1, _MAX_RETRIES)
                time.sleep(_RETRY_DELAY)
                continue
            raise BGGError(f'BoardGameGeek is still processing game {bgg_id}. Please try again.')

        if resp.status_code != 200:
            raise BGGError(f'BGG returned HTTP {resp.status_code} for thing {bgg_id}')

        break

    try:
        root = ET.fromstring(resp.text)
    except ET.ParseError as exc:
        raise BGGError(f'Invalid BGG response: {exc}') from exc

    item = root.find('item')
    if item is None:
        raise BGGError(f'Game {bgg_id} not found on BGG')

    primary_name = item.find("name[@type='primary']")
    title = primary_name.get('value', 'Unknown') if primary_name is not None else 'Unknown'

    year_el = item.find('yearpublished')
    year = _int_or_none(year_el.get('value')) if year_el is not None else None

    min_el = item.find('minplayers')
    max_el = item.find('maxplayers')
    time_el = item.find('playingtime')

    return BGGGame(
        bgg_id=bgg_id,
        title=title,
        year_published=year,
        min_players=_int_or_none(min_el.get('value')) if min_el is not None else None,
        max_players=_int_or_none(max_el.get('value')) if max_el is not None else None,
        playing_time=_int_or_none(time_el.get('value')) if time_el is not None else None,
        thumbnail_url=_fix_url(item.findtext('thumbnail', default='')),
        image_url=_fix_url(item.findtext('image', default='')),
    )


def search_games(query: str, limit: int = 10) -> list[BGGGame]:
    """
    Search BGG for board games by name. Returns up to `limit` results with
    full metadata (thumbnail included via a follow-up /thing batch call).

    Raises BGGError on network or API errors.
    """
    search_url = f'{_BGG_BASE}/search'
    headers = _bgg_headers()

    # Step 1: search for matching IDs
    resp = None
    for attempt in range(_MAX_RETRIES):
        time.sleep(_REQUEST_DELAY)
        try:
            resp = requests.get(
                search_url,
                params={'query': query, 'type': 'boardgame'},
                headers=headers,
                timeout=30,
            )
        except requests.RequestException as exc:
            raise BGGError(f'Could not reach BoardGameGeek: {exc}') from exc

        if resp.status_code == 202:
            if attempt < _MAX_RETRIES - 1:
                logger.info('BGG returned 202 for search "%s" — retrying (%d/%d)', query, attempt + 1, _MAX_RETRIES)
                time.sleep(_RETRY_DELAY)
                continue
            raise BGGError('BoardGameGeek search is still processing. Please try again.')

        if resp.status_code != 200:
            raise BGGError(f'BGG search returned HTTP {resp.status_code}')

        break

    try:
        root = ET.fromstring(resp.text)
    except ET.ParseError as exc:
        raise BGGError(f'Invalid BGG search response: {exc}') from exc

    # Collect BGG IDs from search results
    ids = []
    for item in root.findall('item'):
        bgg_id = _int_or_none(item.get('objectid') or item.get('id'))
        if bgg_id:
            ids.append(bgg_id)
        if len(ids) >= limit:
            break

    if not ids:
        return []

    # Step 2: batch-fetch full metadata (includes thumbnails) for the matched IDs
    thing_url = f'{_BGG_BASE}/thing'
    resp = None
    for attempt in range(_MAX_RETRIES):
        time.sleep(_REQUEST_DELAY)
        try:
            resp = requests.get(
                thing_url,
                params={'id': ','.join(str(i) for i in ids), 'type': 'boardgame'},
                headers=headers,
                timeout=30,
            )
        except requests.RequestException as exc:
            raise BGGError(f'Could not reach BoardGameGeek: {exc}') from exc

        if resp.status_code == 202:
            if attempt < _MAX_RETRIES - 1:
                logger.info('BGG returned 202 for thing batch — retrying (%d/%d)', attempt + 1, _MAX_RETRIES)
                time.sleep(_RETRY_DELAY)
                continue
            raise BGGError('BoardGameGeek is still processing game data. Please try again.')

        if resp.status_code != 200:
            raise BGGError(f'BGG thing batch returned HTTP {resp.status_code}')

        break

    try:
        root = ET.fromstring(resp.text)
    except ET.ParseError as exc:
        raise BGGError(f'Invalid BGG thing response: {exc}') from exc

    # Return in the same order as the search results
    games_by_id: dict[int, BGGGame] = {}
    for item in root.findall('item'):
        bgg_id = _int_or_none(item.get('id'))
        if bgg_id is None:
            continue
        primary_name = item.find("name[@type='primary']")
        title = primary_name.get('value', 'Unknown') if primary_name is not None else 'Unknown'
        year_el = item.find('yearpublished')
        year = _int_or_none(year_el.get('value')) if year_el is not None else None
        min_el = item.find('minplayers')
        max_el = item.find('maxplayers')
        time_el = item.find('playingtime')
        games_by_id[bgg_id] = BGGGame(
            bgg_id=bgg_id,
            title=title,
            year_published=year,
            min_players=_int_or_none(min_el.get('value')) if min_el is not None else None,
            max_players=_int_or_none(max_el.get('value')) if max_el is not None else None,
            playing_time=_int_or_none(time_el.get('value')) if time_el is not None else None,
            thumbnail_url=_fix_url(item.findtext('thumbnail', default='')),
            image_url=_fix_url(item.findtext('image', default='')),
        )

    return [games_by_id[i] for i in ids if i in games_by_id]


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
