"""
GameUPC.com API client.

GameUPC is a crowdsourced barcode → board game database.
Endpoint: https://www.gameupc.com/api/v1/

Used exclusively by the mobile app barcode scan flow (REQ-CM-020 through REQ-CM-024).
The web app may also call this to submit community UPC contributions (REQ-CM-030 through REQ-CM-037).
"""

import logging
from dataclasses import dataclass
from typing import Optional

import requests

logger = logging.getLogger(__name__)

_BASE = 'https://www.gameupc.com/api/v1'
_TIMEOUT = 10


@dataclass
class GameUPCResult:
    upc: str
    title: str
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
    url = f'{_BASE}/game/{upc}'
    try:
        resp = requests.get(url, timeout=_TIMEOUT)
    except requests.RequestException as exc:
        raise GameUPCError(f'Could not reach GameUPC: {exc}') from exc

    if resp.status_code == 404:
        raise GameNotFound(f'No game found for barcode {upc}')

    if resp.status_code != 200:
        logger.error('GameUPC error %s for UPC %s: %s', resp.status_code, upc, resp.text[:200])
        raise GameUPCError(f'GameUPC returned HTTP {resp.status_code}')

    data = resp.json()

    return GameUPCResult(
        upc=upc,
        title=data.get('name') or data.get('title') or 'Unknown',
        year_published=_int_or_none(data.get('year') or data.get('year_published')),
        min_players=_int_or_none(data.get('min_players')),
        max_players=_int_or_none(data.get('max_players')),
        playing_time=_int_or_none(data.get('playing_time')),
        thumbnail_url=data.get('thumbnail') or data.get('thumbnail_url') or '',
        image_url=data.get('image') or data.get('image_url') or '',
    )


def submit_barcode_mapping(upc: str, game_bgg_id: int, user_id: int) -> bool:
    """
    Submit a user-verified UPC → game mapping back to GameUPC (REQ-CM-033, REQ-CM-036).

    Returns True on success, False on failure (errors are non-fatal).
    """
    url = f'{_BASE}/game'
    payload = {
        'upc': upc,
        'bgg_id': game_bgg_id,
        'user_id': user_id,
    }
    try:
        resp = requests.post(url, json=payload, timeout=_TIMEOUT)
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
