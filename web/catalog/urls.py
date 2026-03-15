from django.urls import path

from . import views

app_name = 'catalog'

urlpatterns = [
    path('', views.CollectionView.as_view(), name='collection'),
    path('dismiss-banner/', views.DismissBannerView.as_view(), name='dismiss_banner'),
    path('sync-bgg/', views.SyncBGGView.as_view(), name='sync_bgg'),
]
