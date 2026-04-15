"""
Unit tests for APIKeyAuthentication DRF backend.
"""
from django.test import RequestFactory, TestCase
from rest_framework.exceptions import AuthenticationFailed

from accounts.authentication import APIKeyAuthentication
from accounts.models import APIKey, User


class APIKeyAuthenticationTests(TestCase):
    def setUp(self):
        self.auth = APIKeyAuthentication()
        self.rf = RequestFactory()

        self.user = User.objects.create_user(
            username='authuser',
            email='auth@example.com',
            password='pass',
            email_verified=True,
            is_active=True,
        )
        self.api_key = APIKey.generate(self.user, name='Test')

    # ── Header parsing ────────────────────────────────────────────────────────

    def test_missing_header_returns_none(self):
        request = self.rf.get('/')
        result = self.auth.authenticate(request)
        self.assertIsNone(result)

    def test_non_bearer_header_returns_none(self):
        request = self.rf.get('/', HTTP_AUTHORIZATION='Token abc123')
        result = self.auth.authenticate(request)
        self.assertIsNone(result)

    def test_bearer_prefix_only_raises(self):
        """'Bearer ' with no key after it should fail (key not found)."""
        request = self.rf.get('/', HTTP_AUTHORIZATION='Bearer ')
        with self.assertRaises(AuthenticationFailed):
            self.auth.authenticate(request)

    # ── Key validation ────────────────────────────────────────────────────────

    def test_invalid_key_raises(self):
        request = self.rf.get('/', HTTP_AUTHORIZATION='Bearer notarealkey')
        with self.assertRaises(AuthenticationFailed):
            self.auth.authenticate(request)

    def test_revoked_key_raises(self):
        self.api_key.is_active = False
        self.api_key.save()
        request = self.rf.get('/', HTTP_AUTHORIZATION=f'Bearer {self.api_key.key}')
        with self.assertRaises(AuthenticationFailed):
            self.auth.authenticate(request)

    # ── User state checks ─────────────────────────────────────────────────────

    def test_inactive_user_raises(self):
        self.user.is_active = False
        self.user.save()
        request = self.rf.get('/', HTTP_AUTHORIZATION=f'Bearer {self.api_key.key}')
        with self.assertRaises(AuthenticationFailed):
            self.auth.authenticate(request)

    def test_unverified_email_raises(self):
        self.user.email_verified = False
        self.user.save()
        request = self.rf.get('/', HTTP_AUTHORIZATION=f'Bearer {self.api_key.key}')
        with self.assertRaises(AuthenticationFailed):
            self.auth.authenticate(request)

    # ── Success path ──────────────────────────────────────────────────────────

    def test_valid_key_returns_user_and_key(self):
        request = self.rf.get('/', HTTP_AUTHORIZATION=f'Bearer {self.api_key.key}')
        result = self.auth.authenticate(request)
        self.assertIsNotNone(result)
        returned_user, returned_key = result
        self.assertEqual(returned_user, self.user)
        self.assertEqual(returned_key, self.api_key)

    def test_valid_key_updates_last_used_at(self):
        self.assertIsNone(self.api_key.last_used_at)
        request = self.rf.get('/', HTTP_AUTHORIZATION=f'Bearer {self.api_key.key}')
        self.auth.authenticate(request)
        self.api_key.refresh_from_db()
        self.assertIsNotNone(self.api_key.last_used_at)

    def test_authenticate_header_returns_bearer(self):
        request = self.rf.get('/')
        self.assertEqual(self.auth.authenticate_header(request), 'Bearer')
