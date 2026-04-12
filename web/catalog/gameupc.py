"""
GameUPC.com API client.

GameUPC is a crowdsourced barcode → board game database.
API base: https://api.gameupc.com/v1/  (production)
          https://api.gameupc.com/test/ (test — free, periodically wiped)

Authentication: x-api-key header.
  - Test key:       test_test_test_test_test  (use with /test/ base)
  - Production key: email gameupc@grettir.org to request access.

Used exclusively by the mobile app barcode scan flow (REQ-CM-020 through REQ-CM-024).
"""

import logging
from dataclasses import dataclass
from typing import Optional

import requests
from django.conf import settings

logger = logging.getLogger(__name__)

_TIMEOUT = 10


def _base_url() -> str:
    key = getattr(settings, 'GAMEUPC_API_KEY', '')
    if not key or key.startswith('CHANGE-ME'):
        return 'https://api.gameupc.com/test'
    return 'https://api.gameupc.com/v1'


def _api_key() -> str:
    key = getattr(settings, 'GAMEUPC_API_KEY', '')
    if not key or key.startswith('CHANGE-ME'):
        return 'test_test_test_test_test'
    return key


@dataclass
class GameUPCResult:
    upc: str
    title: str
    bgg_id: Optional[int]
    year_published: Optional[int]
    min_players: Optional[int]
    max_players: Optional[int]
    playing_time: Optional[int]
    thumbnail_url: str
    image_url: str


class GameUPCError(Exception):
    """Raised when the GameUPC API cannot be reached or returns an error."""


class GameNotFound(GameUPCError):
    """Raised when no game is found for the given barcode."""


def lookup_barcode(upc: str) -> GameUPCResult:
    """
    Look up a board game by UPC/barcode via GameUPC.com.

    Returns a GameUPCResult on success.
    Raises GameNotFound if the barcode is not in the database.
    Raises GameUPCError on network or API errors.
    """
    url = f'{_base_url()}/upc/{upc}'
    headers = {'x-api-key': _api_key()}
    try:
        resp = requests.get(url, headers=headers, timeout=_TIMEOUT)
    except requests.RequestException as exc:
        raise GameUPCError(f'Could not reach GameUPC: {exc}') from exc

    if resp.status_code == 404:
        raise GameNotFound(f'No game found for barcode {upc}')

    if resp.status_code != 200:
        logger.error('GameUPC error %s for UPC %s: %s', resp.status_code, upc, resp.text[:200])
        raise GameUPCError(f'GameUPC returned HTTP {resp.status_code}')

    data = resp.json()

    # "new: true" means the UPC is not in the database yet
    if data.get('new') or not data.get('bgg_info'):
        raise GameNotFound(f'No game found for barcode {upc}')

    # Take the highest-confidence result (first entry)
    game = data['bgg_info'][0]

    return GameUPCResult(
        upc=upc,
        title=game.get('name') or game.get('title') or 'Unknown',
        bgg_id=_int_or_none(game.get('bgg_id') or game.get('id')),
        year_published=_int_or_none(game.get('year_published') or game.get('year')),
        min_players=_int_or_none(game.get('min_players')),
        max_players=_int_or_none(game.get('max_players')),
        playing_time=_int_or_none(game.get('playing_time')),
        thumbnail_url=game.get('thumbnail') or game.get('thumbnail_url') or '',
        image_url=game.get('image') or game.get('image_url') or '',
    )


def submit_barcode_mapping(upc: str, game_bgg_id: int, user_id: int) -> bool:
    """
    Submit a user-verified UPC → game mapping back to GameUPC (REQ-CM-033, REQ-CM-036).
    Uses POST /upc/{upc}/bgg_id/{bgg_id} — the community voting endpoint.

    user_id is hashed before transmission so the contributor is anonymous (REQ-CM-036).
    Returns True on success, False on failure (errors are non-fatal).
    """
    import hashlib
    url = f'{_base_url()}/upc/{upc}/bgg_id/{game_bgg_id}'
    headers = {'x-api-key': _api_key()}
    contributor_id = hashlib.sha256(str(user_id).encode()).hexdigest()
    try:
        resp = requests.post(url, headers=headers, json={'user_id': contributor_id}, timeout=_TIMEOUT)
        if resp.status_code in (200, 201):
            logger.info('GameUPC mapping submitted: UPC %s → BGG %s', upc, game_bgg_id)
            return True
        logger.warning('GameUPC submission failed %s for UPC %s', resp.status_code, upc)
        return False
    except requests.RequestException as exc:
        logger.warning('GameUPC submission error for UPC %s: %s', upc, exc)
        return False


def _int_or_none(value) -> Optional[int]:
    try:
        v = int(value)
        return v if v > 0 else None
    except (TypeError, ValueError):
        return None
