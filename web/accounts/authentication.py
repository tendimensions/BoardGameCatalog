from django.utils import timezone
from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed

from .models import APIKey


class APIKeyAuthentication(BaseAuthentication):
    """
    DRF authentication backend for the mobile app.
    Expects:  Authorization: Bearer <api_key>
    Updates last_used_at on each successful request.
    (REQ-MA-001 through REQ-MA-005)
    """

    def authenticate(self, request):
        auth_header = request.META.get('HTTP_AUTHORIZATION', '')
        if not auth_header.startswith('Bearer '):
            return None

        raw_key = auth_header[7:]  # strip 'Bearer '

        try:
            api_key = APIKey.objects.select_related('user').get(
                key=raw_key, is_active=True
            )
        except APIKey.DoesNotExist:
            raise AuthenticationFailed('Invalid or revoked API key.')

        if not api_key.user.is_active or not api_key.user.email_verified:
            raise AuthenticationFailed('User account is not active.')

        api_key.last_used_at = timezone.now()
        api_key.save(update_fields=['last_used_at'])

        return (api_key.user, api_key)

    def authenticate_header(self, request):
        return 'Bearer'
