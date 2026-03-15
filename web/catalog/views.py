from django.contrib import messages
from django.contrib.auth.mixins import LoginRequiredMixin
from django.core.paginator import Paginator
from django.db.models import Q
from django.http import HttpResponse
from django.shortcuts import render, redirect
from django.views import View

from .models import UserCollection

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
    Placeholder for BoardGameGeek sync (REQ-CM-010 through REQ-CM-015).
    Full implementation in Phase 2.
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

        messages.info(
            request,
            f'Syncing with BoardGameGeek for "{request.user.bgg_username}" — '
            'this feature is coming in Phase 2.',
        )
        return redirect('catalog:collection')
