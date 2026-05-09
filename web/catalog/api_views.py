"""
Phase 3 REST API views consumed by the Flutter mobile app.
All endpoints under /api/v1/ (configured in boardgame_catalog/urls.py).

Authentication: Bearer <api_key> on all endpoints except LoginView.
"""

import logging

from django.contrib.auth import authenticate
from django.db.models import Q
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from django.shortcuts import get_object_or_404

from accounts.models import APIKey
from . import bgg as bgg_client
from . import gameupc as gameupc_client
from .bgg import BGGError
from .gameupc import GameNotFound, GameUPCCandidates, GameUPCError, GameUPCResult
from .models import Game, GameList, GameListEntry, UserCollection, UnlinkedBarcode
from .serializers import (
    CollectionItemSerializer,
    GameListDetailSerializer,
    GameListEntrySerializer,
    GameListSerializer,
    GameSerializer,
)

logger = logging.getLogger(__name__)


# ── Auth ──────────────────────────────────────────────────────────────────────

class LoginView(APIView):
    """
    POST /api/v1/auth/login

    Authenticates with username + password and returns an API key for use
    by the mobile app.  Creates a key named "Mobile" on first login; returns
    the same key on subsequent logins so the app always has a stable key.

    Request:  { "username": "...", "password": "..." }
    Response: { "api_key": "...", "user": { ... } }
    """

    authentication_classes = []
    permission_classes = [AllowAny]

    def post(self, request):
        username = request.data.get('username', '').strip()
        password = request.data.get('password', '')

        if not username or not password:
            return Response(
                {'error': 'username and password are required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = authenticate(request, username=username, password=password)
        if user is None:
            return Response(
                {'error': 'Invalid username or password.'},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        if not user.email_verified:
            return Response(
                {'error': 'Email address not verified. Check your inbox.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        if not user.is_active:
            return Response(
                {'error': 'Account is disabled.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        # Return existing mobile key or create a new one.
        api_key_obj = (
            user.api_keys.filter(is_active=True, name='Mobile').first()
            or APIKey.generate(user, name='Mobile')
        )

        return Response({
            'api_key': api_key_obj.key,
            'user': {
                'id': user.id,
                'username': user.username,
                'email': user.email,
                'bgg_username': user.bgg_username,
            },
        })


# ── User ──────────────────────────────────────────────────────────────────────

class UserProfileView(APIView):
    """GET /api/v1/users/profile — returns the authenticated user's profile."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        return Response({
            'id': user.id,
            'username': user.username,
            'email': user.email,
            'bgg_username': user.bgg_username,
        })


# ── Collection ────────────────────────────────────────────────────────────────

class APICollectionView(APIView):
    """
    GET /api/v1/collection

    Returns the authenticated user's game collection.
    Query params: q, sort (title|year|players|time), order (asc|desc),
                  limit (default 50, max 200), offset (default 0).
    """

    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = (
            UserCollection.objects
            .filter(user=request.user)
            .select_related('game')
        )

        q = request.GET.get('q', '').strip()
        if q:
            qs = qs.filter(
                Q(game__title__icontains=q) | Q(game__description__icontains=q)
            )

        sort_map = {
            'title':   'game__title',
            'year':    'game__year_published',
            'players': 'game__min_players',
            'time':    'game__playing_time',
        }
        sort_field = sort_map.get(request.GET.get('sort', 'title'), 'game__title')
        if request.GET.get('order', 'asc') == 'desc':
            sort_field = f'-{sort_field}'
        qs = qs.order_by(sort_field)

        try:
            limit = min(int(request.GET.get('limit', 50)), 200)
            offset = int(request.GET.get('offset', 0))
        except (ValueError, TypeError):
            limit, offset = 50, 0

        total = qs.count()
        page = qs[offset: offset + limit]

        return Response({
            'total_count': total,
            'limit': limit,
            'offset': offset,
            'games': CollectionItemSerializer(page, many=True).data,
        })


# ── Barcode scan ──────────────────────────────────────────────────────────────

class BarcodeScanView(APIView):
    """
    POST /api/v1/scan/barcode

    Process a barcode scan from the mobile app (REQ-CM-020 through REQ-CM-024).
    Optionally add the resolved game to a list when list_id is supplied (REQ-GL-035 through REQ-GL-040).

    Request:  { "upc": "012345678901", "list_id": 7 }   ← list_id is optional (Mode B)

    Three response shapes depending on GameUPC result:
      Case 1 (verified):   HTTP 200/201 with game data
      Case 2 (ambiguous):  HTTP 200 with status: "needs_selection" and suggestions array
      Case 3 (unknown):    HTTP 404 with awaiting_link: true; UnlinkedBarcode saved
    """

    permission_classes = [IsAuthenticated]

    def post(self, request):
        upc = (request.data.get('upc') or '').strip()
        if not upc:
            return Response(
                {'error': 'upc is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # ── Optional list target (Mode B — REQ-GL-035) ────────────────────────
        list_id = request.data.get('list_id')
        target_list = None
        if list_id:
            try:
                target_list = GameList.objects.get(id=list_id, user=request.user)
            except GameList.DoesNotExist:
                return Response(
                    {'error': 'List not found.'},
                    status=status.HTTP_404_NOT_FOUND,
                )

        # ── Step 1: GameUPC lookup ────────────────────────────────────────────
        try:
            lookup = gameupc_client.lookup_barcode(upc)
        except GameNotFound:
            # Case 3 — save the barcode so the user can link it (REQ-CM-040)
            UnlinkedBarcode.objects.update_or_create(
                user=request.user,
                upc=upc,
                defaults={},
            )
            response_body = {
                'error': f'Barcode {upc} was not found in GameUPC. '
                         'It has been saved — you can link it to a game in your collection.',
                'upc': upc,
                'awaiting_link': True,
            }
            if target_list:
                response_body['active_list_name'] = target_list.name
            return Response(response_body, status=status.HTTP_404_NOT_FOUND)
        except GameUPCError as exc:
            logger.warning('GameUPC error for UPC %s: %s', upc, exc)
            return Response(
                {'error': 'Could not reach GameUPC. Please try again.'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        # ── Case 2 — ambiguous: return candidates, do not add to collection ───
        if isinstance(lookup, GameUPCCandidates):
            suggestions = [
                {
                    'bgg_id': c.bgg_id,
                    'title': c.title,
                    'year_published': c.year_published,
                    'thumbnail_url': c.thumbnail_url,
                    'confidence': c.confidence,
                }
                for c in lookup.candidates
            ]
            response_body = {
                'status': 'needs_selection',
                'upc': upc,
                'suggestions': suggestions,
            }
            if target_list:
                response_body['active_list_name'] = target_list.name
            return Response(response_body, status=status.HTTP_200_OK)

        # ── Case 1 — verified: auto-resolve ───────────────────────────────────
        result = lookup  # GameUPCResult
        candidate = result.candidate
        updated_existing = False

        game = Game.objects.filter(upc=upc).first()

        if game is None and candidate.title != 'Unknown':
            game = Game.objects.filter(title__iexact=candidate.title).first()

        if game is None:
            game = Game.objects.create(
                upc=upc,
                bgg_id=candidate.bgg_id,
                title=candidate.title,
                year_published=candidate.year_published,
                min_players=candidate.min_players,
                max_players=candidate.max_players,
                playing_time=candidate.playing_time,
                thumbnail_url=candidate.thumbnail_url,
                image_url=candidate.image_url,
            )
        elif not game.upc:
            game.upc = upc
            game.save(update_fields=['upc', 'updated_at'])
            updated_existing = True

        _, added_to_collection = UserCollection.objects.get_or_create(
            user=request.user,
            game=game,
            defaults={'source': UserCollection.SOURCE_BARCODE},
        )

        response_body = {
            'game': GameSerializer(game).data,
            'added_to_collection': added_to_collection,
            'updated_existing': updated_existing,
        }

        if target_list:
            _, added_to_list = GameListEntry.objects.get_or_create(
                game_list=target_list,
                game=game,
                defaults={'added_via': GameListEntry.VIA_BARCODE},
            )
            response_body['added_to_list'] = added_to_list
            response_body['already_on_list'] = not added_to_list
            if added_to_list:
                logger.info(
                    'User %s scanned %s → added to list "%s"',
                    request.user.username, game.title, target_list.name,
                )
            else:
                logger.info(
                    'User %s scanned %s → already on list "%s"',
                    request.user.username, game.title, target_list.name,
                )

        http_status = status.HTTP_201_CREATED if added_to_collection else status.HTTP_200_OK
        return Response(response_body, status=http_status)


class ConfirmScanView(APIView):
    """
    POST /api/v1/scan/confirm

    Handles the user's candidate selection for Case 2 (ambiguous barcode).

    Request:  { "upc": "222222222224", "bgg_id": 284108 }
    Response: { "game": {...}, "added_to_collection": bool, "submitted_to_gameupc": bool }

    Fetches game metadata from BGG if not already in DB, adds to collection,
    stamps the UPC, and submits the mapping to GameUPC.
    """

    permission_classes = [IsAuthenticated]

    def post(self, request):
        upc = (request.data.get('upc') or '').strip()
        bgg_id = request.data.get('bgg_id')

        if not upc or not bgg_id:
            return Response(
                {'error': 'upc and bgg_id are required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            bgg_id = int(bgg_id)
        except (TypeError, ValueError):
            return Response({'error': 'bgg_id must be an integer.'}, status=status.HTTP_400_BAD_REQUEST)

        game = Game.objects.filter(bgg_id=bgg_id).first()

        if game is None:
            try:
                bgg_game = bgg_client.fetch_thing(bgg_id)
            except BGGError as exc:
                logger.warning('BGG fetch_thing failed for bgg_id %s: %s', bgg_id, exc)
                return Response(
                    {'error': 'Could not fetch game data from BoardGameGeek. Please try again.'},
                    status=status.HTTP_503_SERVICE_UNAVAILABLE,
                )
            game = Game.objects.create(
                upc=upc,
                bgg_id=bgg_game.bgg_id,
                title=bgg_game.title,
                year_published=bgg_game.year_published,
                min_players=bgg_game.min_players,
                max_players=bgg_game.max_players,
                playing_time=bgg_game.playing_time,
                thumbnail_url=bgg_game.thumbnail_url,
                image_url=bgg_game.image_url,
            )
        else:
            if not game.upc:
                game.upc = upc
                game.save(update_fields=['upc', 'updated_at'])

        _, added_to_collection = UserCollection.objects.get_or_create(
            user=request.user,
            game=game,
            defaults={'source': UserCollection.SOURCE_BARCODE},
        )

        submitted = gameupc_client.submit_barcode_mapping(upc, bgg_id, request.user.id)

        logger.info(
            'User %s confirmed barcode %s → game %s (BGG %s), submitted=%s',
            request.user.username, upc, game.title, bgg_id, submitted,
        )

        http_status = status.HTTP_201_CREATED if added_to_collection else status.HTTP_200_OK
        return Response(
            {
                'game': GameSerializer(game).data,
                'added_to_collection': added_to_collection,
                'submitted_to_gameupc': submitted,
            },
            status=http_status,
        )


# ── Unknown barcode linking ───────────────────────────────────────────────────

class LinkBarcodeView(APIView):
    """
    POST /api/v1/scan/link

    Links a previously unrecognised barcode to a game.

    Two modes — exactly one of game_id or bgg_id must be supplied:

    Mode A (collection game):
      Request:  { "upc": "...", "game_id": 42 }
      The game must already be in the user's collection.

    Mode B (BGG search result — Case 3 extended path):
      Request:  { "upc": "...", "bgg_id": 12345 }
      The game is fetched from BGG, created if new, added to collection.

    Response: { "game": {...}, "submitted_to_gameupc": bool }
    """

    permission_classes = [IsAuthenticated]

    def post(self, request):
        upc = (request.data.get('upc') or '').strip()
        game_id = request.data.get('game_id')
        bgg_id = request.data.get('bgg_id')

        if not upc:
            return Response({'error': 'upc is required.'}, status=status.HTTP_400_BAD_REQUEST)

        if not game_id and not bgg_id:
            return Response(
                {'error': 'Either game_id or bgg_id is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if game_id and bgg_id:
            return Response(
                {'error': 'Provide either game_id or bgg_id, not both.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Verify the pending barcode belongs to this user (REQ-CM-040)
        unlinked = get_object_or_404(UnlinkedBarcode, user=request.user, upc=upc)

        if game_id:
            return self._link_by_game_id(request, upc, game_id, unlinked)
        else:
            return self._link_by_bgg_id(request, upc, int(bgg_id), unlinked)

    def _link_by_game_id(self, request, upc, game_id, unlinked):
        """Link to a game already in the user's collection."""
        try:
            collection_item = (
                UserCollection.objects
                .select_related('game')
                .get(user=request.user, game_id=game_id)
            )
        except UserCollection.DoesNotExist:
            return Response(
                {'error': 'Game not found in your collection.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        game = collection_item.game

        if game.upc:
            return Response(
                {'error': 'This game already has a barcode linked.'},
                status=status.HTTP_409_CONFLICT,
            )

        game.upc = upc
        game.save(update_fields=['upc', 'updated_at'])

        submitted = False
        if game.bgg_id:
            submitted = gameupc_client.submit_barcode_mapping(upc, game.bgg_id, request.user.id)
            if submitted:
                logger.info(
                    'User %s linked barcode %s → game %s (BGG %s) and submitted to GameUPC',
                    request.user.username, upc, game.title, game.bgg_id,
                )
            else:
                logger.warning(
                    'User %s linked barcode %s → game %s but GameUPC submission failed',
                    request.user.username, upc, game.title,
                )
        else:
            logger.info(
                'User %s linked barcode %s → game %s (no BGG ID, skipping GameUPC)',
                request.user.username, upc, game.title,
            )

        unlinked.delete()

        return Response(
            {'game': GameSerializer(game).data, 'submitted_to_gameupc': submitted},
            status=status.HTTP_200_OK,
        )

    def _link_by_bgg_id(self, request, upc, bgg_id, unlinked):
        """Fetch game from BGG, create if new, add to collection, submit to GameUPC."""
        game = Game.objects.filter(bgg_id=bgg_id).first()

        if game is None:
            try:
                bgg_game = bgg_client.fetch_thing(bgg_id)
            except BGGError as exc:
                logger.warning('BGG fetch_thing failed for bgg_id %s: %s', bgg_id, exc)
                return Response(
                    {'error': 'Could not fetch game data from BoardGameGeek. Please try again.'},
                    status=status.HTTP_503_SERVICE_UNAVAILABLE,
                )
            game = Game.objects.create(
                upc=upc,
                bgg_id=bgg_game.bgg_id,
                title=bgg_game.title,
                year_published=bgg_game.year_published,
                min_players=bgg_game.min_players,
                max_players=bgg_game.max_players,
                playing_time=bgg_game.playing_time,
                thumbnail_url=bgg_game.thumbnail_url,
                image_url=bgg_game.image_url,
            )
        else:
            if not game.upc:
                game.upc = upc
                game.save(update_fields=['upc', 'updated_at'])

        UserCollection.objects.get_or_create(
            user=request.user,
            game=game,
            defaults={'source': UserCollection.SOURCE_BARCODE},
        )

        submitted = gameupc_client.submit_barcode_mapping(upc, bgg_id, request.user.id)

        logger.info(
            'User %s linked barcode %s → BGG %s via search, submitted=%s',
            request.user.username, upc, bgg_id, submitted,
        )

        unlinked.delete()

        return Response(
            {'game': GameSerializer(game).data, 'submitted_to_gameupc': submitted},
            status=status.HTTP_200_OK,
        )


class DiscardBarcodeView(APIView):
    """
    DELETE /api/v1/scan/unlinked/<upc>

    Discards a saved unlinked barcode without linking it to any game (REQ-CM-048).
    Called when the user dismisses the linking interface.
    Silent no-op if the record doesn't exist (e.g. already linked or timed out).
    """

    permission_classes = [IsAuthenticated]

    def delete(self, request, upc):
        UnlinkedBarcode.objects.filter(user=request.user, upc=upc).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


# ── BGG game search ───────────────────────────────────────────────────────────

class GameSearchView(APIView):
    """
    GET /api/v1/games/search?q=<name>

    Proxies a BGG name search for the Case 3 "Search BGG" tab in LinkBarcodeScreen.
    Returns up to 10 results (bgg_id, title, year_published, thumbnail_url).
    Also annotates each result with already_owned=true if it's in the user's collection.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request):
        query = request.GET.get('q', '').strip()
        if not query:
            return Response({'error': 'q is required.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            results = bgg_client.search_games(query, limit=10)
        except BGGError as exc:
            logger.warning('BGG search failed for query "%s": %s', query, exc)
            return Response(
                {'error': 'Could not reach BoardGameGeek. Please try again.'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        # Determine which results are already in the user's collection
        result_bgg_ids = [g.bgg_id for g in results]
        owned_bgg_ids = set(
            UserCollection.objects
            .filter(user=request.user, game__bgg_id__in=result_bgg_ids)
            .values_list('game__bgg_id', flat=True)
        )

        games = [
            {
                'bgg_id': g.bgg_id,
                'title': g.title,
                'year_published': g.year_published,
                'min_players': g.min_players,
                'max_players': g.max_players,
                'playing_time': g.playing_time,
                'thumbnail_url': g.thumbnail_url,
                'image_url': g.image_url,
                'already_owned': g.bgg_id in owned_bgg_ids,
            }
            for g in results
        ]

        return Response({'games': games})


# ── GameUPC integration test ──────────────────────────────────────────────────

class GameUPCTestView(APIView):
    """
    POST /api/v1/gameupc/test

    Runs all three test UPCs against the configured GameUPC endpoint and returns
    a structured summary.  Used by the Settings page integration test UI.
    No games are added to any collection; no UPCs are submitted to GameUPC.
    """

    _TEST_CASES = [
        ('111111111117', 'verified'),
        ('222222222224', 'ambiguous'),
        ('333333333331', 'unknown'),
    ]

    permission_classes = [IsAuthenticated]

    def post(self, request):
        from . import gameupc as _gu
        env = 'test' if _gu._api_key() == 'test_test_test_test_test' else 'production'

        results = []
        for upc, expected_case in self._TEST_CASES:
            entry = {'upc': upc, 'case': expected_case, 'error': None,
                     'title': None, 'bgg_id': None, 'candidate_count': 0}
            try:
                lookup = gameupc_client.lookup_barcode(upc)
                if isinstance(lookup, GameUPCResult):
                    entry['status'] = 'ok'
                    entry['title'] = lookup.candidate.title
                    entry['bgg_id'] = lookup.candidate.bgg_id
                    entry['candidate_count'] = 1
                elif isinstance(lookup, GameUPCCandidates):
                    entry['status'] = 'ok'
                    entry['candidate_count'] = len(lookup.candidates)
            except GameNotFound:
                entry['status'] = 'ok'
                entry['candidate_count'] = 0
            except GameUPCError as exc:
                entry['status'] = 'error'
                entry['error'] = str(exc)

            results.append(entry)

        return Response({'environment': env, 'results': results})


# ── Game Lists ────────────────────────────────────────────────────────────────

class GameListsView(APIView):
    """
    GET  /api/v1/lists  — return all lists for the authenticated user (REQ-GL-001)
    POST /api/v1/lists  — create a new list (REQ-GL-001)

    POST request: { "name": "Loaned", "description": "" }
    """

    permission_classes = [IsAuthenticated]

    def get(self, request):
        # entry_count is a @property on GameList — no annotation needed.
        # prefetch_related avoids N+1 queries when the list is long.
        lists = (
            GameList.objects
            .filter(user=request.user)
            .prefetch_related('entries')
        )
        return Response(GameListSerializer(lists, many=True).data)

    def post(self, request):
        name = (request.data.get('name') or '').strip()
        if not name:
            return Response(
                {'error': 'name is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        game_list = GameList.objects.create(
            user=request.user,
            name=name,
            description=(request.data.get('description') or '').strip(),
        )
        # entry_count is a @property — no manual assignment needed.
        return Response(
            GameListSerializer(game_list).data,
            status=status.HTTP_201_CREATED,
        )


class GameListDetailView(APIView):
    """
    GET    /api/v1/lists/<list_id>  — return list with all entries (REQ-GL-022)
    PATCH  /api/v1/lists/<list_id>  — update name / description (REQ-GL-002)
    DELETE /api/v1/lists/<list_id>  — delete list (REQ-GL-003)
    """

    permission_classes = [IsAuthenticated]

    def _get_list(self, request, list_id):
        try:
            return GameList.objects.get(id=list_id, user=request.user)
        except GameList.DoesNotExist:
            return None

    def get(self, request, list_id):
        game_list = self._get_list(request, list_id)
        if game_list is None:
            return Response({'error': 'List not found.'}, status=status.HTTP_404_NOT_FOUND)
        # entry_count is a @property — serializer reads it directly.
        return Response(GameListDetailSerializer(game_list).data)

    def patch(self, request, list_id):
        game_list = self._get_list(request, list_id)
        if game_list is None:
            return Response({'error': 'List not found.'}, status=status.HTTP_404_NOT_FOUND)
        if 'name' in request.data:
            name = (request.data['name'] or '').strip()
            if not name:
                return Response({'error': 'name cannot be empty.'}, status=status.HTTP_400_BAD_REQUEST)
            game_list.name = name
        if 'description' in request.data:
            game_list.description = (request.data['description'] or '').strip()
        game_list.save()
        # entry_count is a @property — no manual assignment needed.
        return Response(GameListSerializer(game_list).data)

    def delete(self, request, list_id):
        game_list = self._get_list(request, list_id)
        if game_list is None:
            return Response({'error': 'List not found.'}, status=status.HTTP_404_NOT_FOUND)
        game_list.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class GameListEntriesView(APIView):
    """
    POST /api/v1/lists/<list_id>/entries

    Add a game to a list (REQ-GL-010, REQ-GL-011).
    The game must be in the user's collection.

    Request: { "game_id": 42, "note": "optional note" }
    """

    permission_classes = [IsAuthenticated]

    def post(self, request, list_id):
        try:
            game_list = GameList.objects.get(id=list_id, user=request.user)
        except GameList.DoesNotExist:
            return Response({'error': 'List not found.'}, status=status.HTTP_404_NOT_FOUND)

        game_id = request.data.get('game_id')
        if not game_id:
            return Response({'error': 'game_id is required.'}, status=status.HTTP_400_BAD_REQUEST)

        # Game must be in the user's collection (REQ-GL-010)
        if not UserCollection.objects.filter(user=request.user, game_id=game_id).exists():
            return Response(
                {'error': 'Game not found in your collection.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        entry, created = GameListEntry.objects.get_or_create(
            game_list=game_list,
            game_id=game_id,
            defaults={
                'note': (request.data.get('note') or '').strip(),
                'added_via': GameListEntry.VIA_MANUAL,
            },
        )
        if not created:
            return Response(
                {'error': 'Game is already on this list.'},
                status=status.HTTP_409_CONFLICT,
            )
        return Response(
            GameListEntrySerializer(entry).data,
            status=status.HTTP_201_CREATED,
        )


class GameListEntryDetailView(APIView):
    """
    PATCH  /api/v1/lists/<list_id>/entries/<entry_id>  — update note (REQ-GL-013)
    DELETE /api/v1/lists/<list_id>/entries/<entry_id>  — remove from list (REQ-GL-014)
    """

    permission_classes = [IsAuthenticated]

    def _get_entry(self, request, list_id, entry_id):
        try:
            return GameListEntry.objects.select_related('game').get(
                id=entry_id,
                game_list_id=list_id,
                game_list__user=request.user,
            )
        except GameListEntry.DoesNotExist:
            return None

    def patch(self, request, list_id, entry_id):
        entry = self._get_entry(request, list_id, entry_id)
        if entry is None:
            return Response({'error': 'Entry not found.'}, status=status.HTTP_404_NOT_FOUND)
        entry.note = (request.data.get('note') or '').strip()
        entry.save(update_fields=['note', 'updated_at'])
        return Response(GameListEntrySerializer(entry).data)

    def delete(self, request, list_id, entry_id):
        entry = self._get_entry(request, list_id, entry_id)
        if entry is None:
            return Response({'error': 'Entry not found.'}, status=status.HTTP_404_NOT_FOUND)
        entry.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
