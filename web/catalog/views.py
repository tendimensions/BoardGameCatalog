import logging

from django.contrib import messages
from django.contrib.auth.mixins import LoginRequiredMixin
from django.core.paginator import Paginator
from django.db.models import Q
from django.http import HttpResponse
from django.shortcuts import render, redirect
from django.views import View

from . import bgg as bgg_client
from .models import Game, GameList, GameListEntry, UserCollection

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

        try:
            bgg_games = bgg_client.fetch_collection(request.user.bgg_username)
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


# ── Game Lists ────────────────────────────────────────────────────────────────

class ManageListsView(LoginRequiredMixin, View):
    """
    GET  /lists/  — show all lists (REQ-GL-020, REQ-GL-021)
    POST /lists/  — create a new list (REQ-GL-001)
    """

    login_url = '/accounts/login/'

    def get(self, request):
        from django.db.models import Count
        lists = (
            GameList.objects
            .filter(user=request.user)
            .annotate(entry_count=Count('entries'))
        )
        return render(request, 'catalog/lists.html', {'lists': lists})

    def post(self, request):
        name = request.POST.get('name', '').strip()
        description = request.POST.get('description', '').strip()
        if not name:
            messages.error(request, 'List name is required.')
            return redirect('catalog:lists')
        GameList.objects.create(user=request.user, name=name, description=description)
        messages.success(request, f'List "{name}" created.')
        return redirect('catalog:lists')


class ListDetailView(LoginRequiredMixin, View):
    """GET /lists/<list_id>/  — show list entries (REQ-GL-022, REQ-GL-025)"""

    login_url = '/accounts/login/'

    def get(self, request, list_id):
        try:
            game_list = GameList.objects.get(id=list_id, user=request.user)
        except GameList.DoesNotExist:
            messages.error(request, 'List not found.')
            return redirect('catalog:lists')

        q = request.GET.get('q', '').strip()
        entries = game_list.entries.select_related('game')
        if q:
            entries = entries.filter(game__title__icontains=q)

        return render(request, 'catalog/list_detail.html', {
            'game_list': game_list,
            'entries': entries,
            'search_query': q,
        })


class UpdateListView(LoginRequiredMixin, View):
    """POST /lists/<list_id>/update/  — rename or update description (REQ-GL-002)"""

    login_url = '/accounts/login/'

    def post(self, request, list_id):
        try:
            game_list = GameList.objects.get(id=list_id, user=request.user)
        except GameList.DoesNotExist:
            messages.error(request, 'List not found.')
            return redirect('catalog:lists')

        name = request.POST.get('name', '').strip()
        if not name:
            messages.error(request, 'List name is required.')
            return redirect('catalog:list_detail', list_id=list_id)

        game_list.name = name
        game_list.description = request.POST.get('description', '').strip()
        game_list.save()
        messages.success(request, 'List updated.')
        return redirect('catalog:list_detail', list_id=list_id)


class DeleteListView(LoginRequiredMixin, View):
    """POST /lists/<list_id>/delete/  — delete a list (REQ-GL-003)"""

    login_url = '/accounts/login/'

    def post(self, request, list_id):
        try:
            game_list = GameList.objects.get(id=list_id, user=request.user)
        except GameList.DoesNotExist:
            messages.error(request, 'List not found.')
            return redirect('catalog:lists')

        name = game_list.name
        game_list.delete()
        messages.success(request, f'List "{name}" deleted.')
        return redirect('catalog:lists')


class AddToListView(LoginRequiredMixin, View):
    """
    POST /lists/<list_id>/add/  — add a game to a list from the web UI (REQ-GL-010, REQ-GL-026)

    If the game is not in the user's collection and confirm=1 is posted, it is added
    to the collection first, then to the list.
    """

    login_url = '/accounts/login/'

    def post(self, request, list_id):
        try:
            game_list = GameList.objects.get(id=list_id, user=request.user)
        except GameList.DoesNotExist:
            messages.error(request, 'List not found.')
            return redirect('catalog:lists')

        game_id = request.POST.get('game_id')
        try:
            game = Game.objects.get(id=game_id)
        except (Game.DoesNotExist, TypeError, ValueError):
            messages.error(request, 'Game not found.')
            return redirect('catalog:list_detail', list_id=list_id)

        in_collection = UserCollection.objects.filter(
            user=request.user, game=game
        ).exists()

        if not in_collection:
            if request.POST.get('confirm') != '1':
                # REQ-GL-026: prompt before silently adding to collection
                messages.warning(
                    request,
                    f'"{game.title}" is not in your collection. '
                    'Confirm below to add it to your collection and this list.',
                )
                return render(request, 'catalog/list_detail.html', {
                    'game_list': game_list,
                    'entries': game_list.entries.select_related('game'),
                    'search_query': '',
                    'confirm_add': game,
                })
            UserCollection.objects.get_or_create(
                user=request.user, game=game,
                defaults={'source': UserCollection.SOURCE_MANUAL},
            )

        _, created = GameListEntry.objects.get_or_create(
            game_list=game_list,
            game=game,
            defaults={'added_via': GameListEntry.VIA_MANUAL},
        )
        if created:
            messages.success(request, f'"{game.title}" added to "{game_list.name}".')
        else:
            messages.info(request, f'"{game.title}" is already on this list.')

        return redirect('catalog:list_detail', list_id=list_id)


class RemoveFromListView(LoginRequiredMixin, View):
    """POST /lists/<list_id>/entries/<entry_id>/remove/  — remove game from list (REQ-GL-014)"""

    login_url = '/accounts/login/'

    def post(self, request, list_id, entry_id):
        try:
            entry = GameListEntry.objects.get(
                id=entry_id,
                game_list_id=list_id,
                game_list__user=request.user,
            )
        except GameListEntry.DoesNotExist:
            messages.error(request, 'Entry not found.')
            return redirect('catalog:list_detail', list_id=list_id)

        title = entry.game.title
        entry.delete()
        messages.success(request, f'"{title}" removed from list.')
        return redirect('catalog:list_detail', list_id=list_id)


class UpdateEntryNoteView(LoginRequiredMixin, View):
    """POST /lists/<list_id>/entries/<entry_id>/note/  — update note on entry (REQ-GL-013)"""

    login_url = '/accounts/login/'

    def post(self, request, list_id, entry_id):
        try:
            entry = GameListEntry.objects.select_related('game').get(
                id=entry_id,
                game_list_id=list_id,
                game_list__user=request.user,
            )
        except GameListEntry.DoesNotExist:
            messages.error(request, 'Entry not found.')
            return redirect('catalog:list_detail', list_id=list_id)

        entry.note = request.POST.get('note', '').strip()
        entry.save(update_fields=['note', 'updated_at'])
        messages.success(request, f'Note updated for "{entry.game.title}".')
        return redirect('catalog:list_detail', list_id=list_id)
