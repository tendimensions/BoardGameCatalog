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
from . import gameupc as gameupc_client
from .gameupc import GameNotFound, GameUPCError
from .models import Game, UserCollection, UnlinkedBarcode
from .serializers import CollectionItemSerializer, GameSerializer

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

    Request:  { "upc": "012345678901" }
    Response: { "game": {...}, "added_to_collection": bool, "updated_existing": bool }

    Processing order:
      1. Look up the UPC on GameUPC.com.
      2. If the game already exists in our DB (by UPC or title match), update UPC if missing.
      3. If it doesn't exist, create a new Game record.
      4. Add to the user's collection if not already present.
    """

    permission_classes = [IsAuthenticated]

    def post(self, request):
        upc = (request.data.get('upc') or '').strip()
        if not upc:
            return Response(
                {'error': 'upc is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # ── Step 1: GameUPC lookup ────────────────────────────────────────────
        try:
            result = gameupc_client.lookup_barcode(upc)
        except GameNotFound:
            # Save the barcode so the user can link it to a game (REQ-CM-040).
            # update_or_create handles re-scans of the same unrecognised barcode.
            UnlinkedBarcode.objects.update_or_create(
                user=request.user,
                upc=upc,
                defaults={},
            )
            return Response(
                {
                    'error': f'Barcode {upc} was not found in GameUPC. '
                             'It has been saved — you can link it to a game in your collection.',
                    'upc': upc,
                    'awaiting_link': True,
                },
                status=status.HTTP_404_NOT_FOUND,
            )
        except GameUPCError as exc:
            logger.warning('GameUPC error for UPC %s: %s', upc, exc)
            return Response(
                {'error': 'Could not reach GameUPC. Please try again.'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        # ── Step 2 & 3: Find or create the Game record ────────────────────────
        updated_existing = False

        # First try to find by UPC
        game = Game.objects.filter(upc=upc).first()

        if game is None and result.title != 'Unknown':
            # Fall back to title match (handles games synced from BGG without UPC)
            game = Game.objects.filter(title__iexact=result.title).first()

        if game is None:
            # Create a brand-new game record
            game = Game.objects.create(
                upc=upc,
                bgg_id=result.bgg_id,
                title=result.title,
                year_published=result.year_published,
                min_players=result.min_players,
                max_players=result.max_players,
                playing_time=result.playing_time,
                thumbnail_url=result.thumbnail_url,
                image_url=result.image_url,
            )
        elif not game.upc:
            # Game exists (from BGG sync) but has no UPC — stamp it in
            game.upc = upc
            game.save(update_fields=['upc', 'updated_at'])
            updated_existing = True

        # ── Step 4: Add to collection ─────────────────────────────────────────
        _, added_to_collection = UserCollection.objects.get_or_create(
            user=request.user,
            game=game,
            defaults={'source': UserCollection.SOURCE_BARCODE},
        )

        http_status = status.HTTP_201_CREATED if added_to_collection else status.HTTP_200_OK
        return Response(
            {
                'game': GameSerializer(game).data,
                'added_to_collection': added_to_collection,
                'updated_existing': updated_existing,
            },
            status=http_status,
        )


# ── Unknown barcode linking ───────────────────────────────────────────────────

class LinkBarcodeView(APIView):
    """
    POST /api/v1/scan/link

    Links a previously unrecognised barcode to a game in the user's collection
    and submits the mapping to GameUPC.com as a community contribution
    (REQ-CM-044 through REQ-CM-048).

    Request:  { "upc": "012345678901", "game_id": 42 }
    Response: { "game": {...}, "submitted_to_gameupc": bool }

    The UnlinkedBarcode record is deleted on success.  The game's upc field
    is stamped.  If the game has no bgg_id the GameUPC submission is skipped
    (REQ-CM-047) and submitted_to_gameupc is false.
    """

    permission_classes = [IsAuthenticated]

    def post(self, request):
        upc = (request.data.get('upc') or '').strip()
        game_id = request.data.get('game_id')

        if not upc or not game_id:
            return Response(
                {'error': 'upc and game_id are required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Verify the pending barcode belongs to this user (REQ-CM-040)
        unlinked = get_object_or_404(UnlinkedBarcode, user=request.user, upc=upc)

        # Game must be in the user's collection
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

        # Stamp the UPC onto the game record
        game.upc = upc
        game.save(update_fields=['upc', 'updated_at'])

        # Submit to GameUPC if we have a BGG ID (REQ-CM-045, REQ-CM-047)
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

        # Clean up the pending record (REQ-CM-048)
        unlinked.delete()

        return Response(
            {
                'game': GameSerializer(game).data,
                'submitted_to_gameupc': submitted,
            },
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
