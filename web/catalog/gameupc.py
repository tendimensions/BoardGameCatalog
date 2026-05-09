"""
GameUPC.com API client.

GameUPC is a crowdsourced barcode → board game database.
API base: https://api.gameupc.com/v1/  (production)
          https://api.gameupc.com/test/ (test — free, periodically wiped)

Authentication: x-api-key header.
  - Test key:       test_test_test_test_test  (use with /test/ base)
  - Production key: email gameupc@grettir.org to request access.

Used exclusively by the mobile app barcode scan flow (REQ-CM-020 through REQ-CM-024).

Three response scenarios from the API:
  Case 1 — bgg_info_status: "verified", single entry  → GameUPCResult (auto-resolvable)
  Case 2 — bgg_info_status: "choose_from_bgg_info_or_search", 2+ entries → GameUPCCandidates
  Case 3 — new: true, bgg_info empty → raises GameNotFound
"""

import logging
from dataclasses import dataclass
from typing import Optional, Union

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
class GameUPCCandidate:
    bgg_id: Optional[int]
    title: str
    year_published: Optional[int]
    min_players: Optional[int]
    max_players: Optional[int]
    playing_time: Optional[int]
    thumbnail_url: str
    image_url: str
    confidence: float


@dataclass
class GameUPCResult:
    """Case 1 — verified, single candidate, auto-resolvable."""
    upc: str
    candidate: GameUPCCandidate


@dataclass
class GameUPCCandidates:
    """Case 2 — ambiguous, multiple candidates, user must choose."""
    upc: str
    candidates: list[GameUPCCandidate]


class GameUPCError(Exception):
    """Raised when the GameUPC API cannot be reached or returns an error."""


class GameNotFound(GameUPCError):
    """Raised when no game is found for the given barcode (Case 3)."""


def lookup_barcode(upc: str) -> Union[GameUPCResult, GameUPCCandidates]:
    """
    Look up a board game by UPC/barcode via GameUPC.com.

    Returns GameUPCResult (Case 1 — verified, single match) or
    GameUPCCandidates (Case 2 — ambiguous, multiple matches).
    Raises GameNotFound for Case 3 (new barcode, no bgg_info).
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

    # Case 3 — barcode is new to GameUPC
    if data.get('new') or not data.get('bgg_info'):
        raise GameNotFound(f'No game found for barcode {upc}')

    candidates = [_parse_candidate(g) for g in data['bgg_info']]

    bgg_info_status = data.get('bgg_info_status', '')
    if bgg_info_status == 'choose_from_bgg_info_or_search' or len(candidates) > 1:
        # Case 2 — ambiguous, user must choose
        return GameUPCCandidates(upc=upc, candidates=candidates)

    # Case 1 — verified, single result
    return GameUPCResult(upc=upc, candidate=candidates[0])


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


def _parse_candidate(game: dict) -> GameUPCCandidate:
    return GameUPCCandidate(
        bgg_id=_int_or_none(game.get('bgg_id') or game.get('id')),
        title=game.get('name') or game.get('title') or 'Unknown',
        year_published=_int_or_none(game.get('year_published') or game.get('year')),
        min_players=_int_or_none(game.get('min_players')),
        max_players=_int_or_none(game.get('max_players')),
        playing_time=_int_or_none(game.get('playing_time')),
        thumbnail_url=game.get('thumbnail') or game.get('thumbnail_url') or '',
        image_url=game.get('image') or game.get('image_url') or '',
        confidence=float(game.get('confidence') or 1.0),
    )


def _int_or_none(value) -> Optional[int]:
    try:
        v = int(value)
        return v if v > 0 else None
    except (TypeError, ValueError):
        return None
