# REST API endpoints consumed by the Flutter mobile app.
# URL prefix: /api/v1/  (configured in boardgame_catalog/urls.py)
from django.urls import path

from .api_views import (
    APICollectionView,
    BarcodeScanView,
    DiscardBarcodeView,
    GameListDetailView,
    GameListEntriesView,
    GameListEntryDetailView,
    GameListsView,
    LinkBarcodeView,
    LoginView,
    UserProfileView,
)

urlpatterns = [
    # Auth
    path('auth/login',              LoginView.as_view(),         name='api_login'),
    # User
    path('users/profile',           UserProfileView.as_view(),   name='api_profile'),
    # Collection
    path('collection',              APICollectionView.as_view(), name='api_collection'),
    # Barcode scan
    path('scan/barcode',            BarcodeScanView.as_view(),   name='api_scan_barcode'),
    # Unknown-barcode contribution (REQ-CM-040 through REQ-CM-049)
    path('scan/link',               LinkBarcodeView.as_view(),   name='api_scan_link'),
    path('scan/unlinked/<str:upc>', DiscardBarcodeView.as_view(), name='api_scan_discard'),
    # Game Lists (REQ-GL-001 through REQ-GL-041)
    path('lists',                               GameListsView.as_view(),            name='api_lists'),
    path('lists/<int:list_id>',                 GameListDetailView.as_view(),       name='api_list_detail'),
    path('lists/<int:list_id>/entries',         GameListEntriesView.as_view(),      name='api_list_entries'),
    path('lists/<int:list_id>/entries/<int:entry_id>', GameListEntryDetailView.as_view(), name='api_list_entry_detail'),
]
