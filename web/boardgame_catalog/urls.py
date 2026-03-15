from django.contrib import admin
from django.urls import path, include
from django.views.generic import RedirectView

urlpatterns = [
    path('admin/', admin.site.urls),
    path('accounts/', include('accounts.urls')),
    path('collection/', include('catalog.urls')),
    # API v1 — mobile app endpoints
    path('api/v1/', include('catalog.api_urls')),
    # Root redirect
    path('', RedirectView.as_view(url='/collection/', permanent=False)),
]
