from django.contrib.auth.views import (
    LogoutView,
    PasswordResetView,
    PasswordResetDoneView,
    PasswordResetConfirmView,
    PasswordResetCompleteView,
    PasswordChangeView,
)
from django.urls import path

from . import views

app_name = 'accounts'

urlpatterns = [
    # ── Authentication ────────────────────────────────────────────────────────
    path('login/', views.CustomLoginView.as_view(), name='login'),
    path('logout/', LogoutView.as_view(), name='logout'),
    path('register/', views.RegisterView.as_view(), name='register'),

    # ── Email verification ────────────────────────────────────────────────────
    path('verification-sent/', views.VerificationSentView.as_view(), name='verification_sent'),
    path('verify-email/<str:token>/', views.VerifyEmailView.as_view(), name='verify_email'),

    # ── Profile & API keys ────────────────────────────────────────────────────
    path('profile/', views.ProfileView.as_view(), name='profile'),
    path('api-keys/', views.APIKeyListView.as_view(), name='api_keys'),
    path('api-keys/generate/', views.GenerateAPIKeyView.as_view(), name='generate_api_key'),
    path('api-keys/<int:key_id>/revoke/', views.RevokeAPIKeyView.as_view(), name='revoke_api_key'),

    # ── Password management ───────────────────────────────────────────────────
    path('password-reset/', PasswordResetView.as_view(
        template_name='registration/password_reset_form.html',
        email_template_name='registration/password_reset_email.txt',
        success_url='/accounts/password-reset/done/',
    ), name='password_reset'),

    path('password-reset/done/', PasswordResetDoneView.as_view(
        template_name='registration/password_reset_done.html',
    ), name='password_reset_done'),

    path('reset/<uidb64>/<token>/', PasswordResetConfirmView.as_view(
        template_name='registration/password_reset_confirm.html',
        success_url='/accounts/reset/done/',
    ), name='password_reset_confirm'),

    path('reset/done/', PasswordResetCompleteView.as_view(
        template_name='registration/password_reset_complete.html',
    ), name='password_reset_complete'),

    path('password-change/', PasswordChangeView.as_view(
        template_name='accounts/password_change.html',
        success_url='/accounts/profile/',
    ), name='password_change'),
]
