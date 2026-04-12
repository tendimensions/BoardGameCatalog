# REST API endpoints consumed by the Flutter mobile app.
# URL prefix: /api/v1/  (configured in boardgame_catalog/urls.py)
from django.urls import path

from .api_views import (
    APICollectionView,
    BarcodeScanView,
    DiscardBarcodeView,
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
]
