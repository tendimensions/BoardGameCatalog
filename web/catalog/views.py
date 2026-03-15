import logging

from django.contrib import messages
from django.contrib.auth.mixins import LoginRequiredMixin
from django.core.paginator import Paginator
from django.db.models import Q
from django.http import HttpResponse
from django.shortcuts import render, redirect
from django.views import View

from . import bgg as bgg_client
from .models import Game, UserCollection

logger = logging.getLogger(__name__)

PAGE_SIZE = 25


class CollectionView(LoginRequiredMixin, View):
    """
    Main collection screen (REQ-CM-001 through REQ-CM-007, UI spec §8.2.4).
    Supports search, filter (all / missing_barcode / lent), and sort.
    HTMX requests receive only the game-table partial for in-place updates.
    """

    login_url = '/accounts/login/'
    template_name = 'catalog/collection.html'

    def get(self, request):
        qs = (
            UserCollection.objects
            .filter(user=request.user)
            .select_related('game')
        )

        # ── Search ────────────────────────────────────────────────────────────
        search_query = request.GET.get('q', '').strip()
        if search_query:
            qs = qs.filter(
                Q(game__title__icontains=search_query) |
                Q(game__description__icontains=search_query)
            )

        # ── Filter ────────────────────────────────────────────────────────────
        filter_val = request.GET.get('filter', 'all')
        if filter_val == 'missing_barcode':
            qs = qs.filter(game__upc='')
        elif filter_val == 'lent':
            qs = qs.filter(is_lent=True)

        # ── Sort ──────────────────────────────────────────────────────────────
        sort = request.GET.get('sort', 'title')
        order = request.GET.get('order', 'asc')
        sort_map = {
            'title': 'game__title',
            'year': 'game__year_published',
            'players': 'game__min_players',
            'time': 'game__playing_time',
        }
        sort_field = sort_map.get(sort, 'game__title')
        if order == 'desc':
            sort_field = f'-{sort_field}'
        qs = qs.order_by(sort_field)

        total_count = UserCollection.objects.filter(user=request.user).count()
        filtered_count = qs.count()

        paginator = Paginator(qs, PAGE_SIZE)
        page_obj = paginator.get_page(request.GET.get('page', 1))

        context = {
            'page_obj': page_obj,
            'total_count': total_count,
            'filtered_count': filtered_count,
            'search_query': search_query,
            'filter_val': filter_val,
            'sort': sort,
            'order': order,
            'show_banner': not request.session.get('banner_dismissed', False),
        }

        if request.headers.get('HX-Request'):
            return render(request, 'catalog/partials/game_table.html', context)

        return render(request, self.template_name, context)


class DismissBannerView(LoginRequiredMixin, View):
    """Store banner-dismissed state in session (REQ-CM-034)."""

    login_url = '/accounts/login/'

    def post(self, request):
        request.session['banner_dismissed'] = True
        return HttpResponse('')


class SyncBGGView(LoginRequiredMixin, View):
    """
    Sync the authenticated user's BGG collection (REQ-CM-010 to REQ-CM-015).

    Additive and non-destructive:
      - Games already in the local collection are never removed (REQ-CM-012).
      - Game metadata is refreshed from BGG on each sync (REQ-CM-013).
      - The UPC field is never touched by this sync (REQ-CM-014).
    """

    login_url = '/accounts/login/'

    def post(self, request):
        if not request.user.bgg_username:
            messages.warning(
                request,
                'No BoardGameGeek username on your account. '
                'BGG username can only be set at registration.',
            )
            return redirect('catalog:collection')

        # ── Parse XML posted from the browser ────────────────────────────────
        # The browser fetches BGG directly (avoiding server-side IP blocks) and
        # POSTs the raw XML here for processing.
        xml_data = request.POST.get('xml_data', '').strip()
        if not xml_data:
            messages.error(request, 'No collection data received. Please try again.')
            return redirect('catalog:collection')

        try:
            bgg_games = bgg_client.parse_collection_xml(xml_data)
        except bgg_client.BGGError as exc:
            messages.error(request, f'BGG sync failed: {exc}')
            return redirect('catalog:collection')
        except Exception:
            logger.exception(
                'Unexpected error during BGG sync for user %s', request.user.username
            )
            messages.error(
                request,
                'An unexpected error occurred during sync. Please try again later.',
            )
            return redirect('catalog:collection')

        if not bgg_games:
            messages.info(
                request,
                f'No owned games found on BoardGameGeek for "{request.user.bgg_username}". '
                'Make sure your collection is set to public on BGG.',
            )
            return redirect('catalog:collection')

        # ── Sync each game into the local database ────────────────────────────
        added = 0

        for bg in bgg_games:
            game, created = Game.objects.get_or_create(
                bgg_id=bg.bgg_id,
                defaults={
                    'title':          bg.title,
                    'year_published': bg.year_published,
                    'min_players':    bg.min_players,
                    'max_players':    bg.max_players,
                    'playing_time':   bg.playing_time,
                    'thumbnail_url':  bg.thumbnail_url,
                    'image_url':      bg.image_url,
                },
            )

            if not created:
                # Refresh metadata from BGG but never overwrite the UPC (REQ-CM-014)
                game.title          = bg.title
                game.year_published = bg.year_published
                game.min_players    = bg.min_players
                game.max_players    = bg.max_players
                game.playing_time   = bg.playing_time
                game.thumbnail_url  = bg.thumbnail_url
                game.image_url      = bg.image_url
                game.save(update_fields=[
                    'title', 'year_published', 'min_players', 'max_players',
                    'playing_time', 'thumbnail_url', 'image_url', 'updated_at',
                ])

            _, collection_created = UserCollection.objects.get_or_create(
                user=request.user,
                game=game,
                defaults={'source': UserCollection.SOURCE_BGG},
            )
            if collection_created:
                added += 1

        # ── Result message ────────────────────────────────────────────────────
        if added:
            messages.success(
                request,
                f'Sync complete — {added} new game{"s" if added != 1 else ""} added to your collection.',
            )
        else:
            messages.info(request, 'Sync complete — your collection is already up to date.')

        return redirect('catalog:collection')
