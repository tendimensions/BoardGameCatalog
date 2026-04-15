"""
Unit tests for accounts models: User, APIKey.
"""
import re
from django.test import TestCase

from accounts.models import APIKey, User


class UserGenerateVerificationTokenTests(TestCase):
    def _make_user(self, **kwargs):
        defaults = {
            'username': 'tokenuser',
            'email': 'tokenuser@example.com',
            'password': 'testpass123',
            'is_active': False,
        }
        defaults.update(kwargs)
        return User.objects.create_user(**defaults)

    def test_returns_urlsafe_string(self):
        user = self._make_user()
        token = user.generate_verification_token()
        # secrets.token_urlsafe output is base64url — no +, /, = chars
        self.assertRegex(token, r'^[A-Za-z0-9_\-]+$')

    def test_token_persisted_on_user(self):
        user = self._make_user()
        token = user.generate_verification_token()
        user.refresh_from_db()
        self.assertEqual(user.verification_token, token)

    def test_token_minimum_length(self):
        """secrets.token_urlsafe(32) produces at least 32 bytes of entropy."""
        user = self._make_user()
        token = user.generate_verification_token()
        self.assertGreaterEqual(len(token), 32)

    def test_successive_calls_produce_different_tokens(self):
        user = self._make_user()
        t1 = user.generate_verification_token()
        t2 = user.generate_verification_token()
        self.assertNotEqual(t1, t2)


class UserFieldTests(TestCase):
    def test_email_verified_defaults_false(self):
        u = User.objects.create_user(
            username='newuser', email='new@example.com', password='pass'
        )
        self.assertFalse(u.email_verified)

    def test_bgg_username_optional(self):
        u = User.objects.create_user(
            username='nobgg', email='nobgg@example.com', password='pass'
        )
        self.assertEqual(u.bgg_username, '')

    def test_is_active_defaults_true_via_create_user(self):
        """Django's create_user sets is_active=True by default."""
        u = User.objects.create_user(
            username='active', email='active@example.com', password='pass'
        )
        self.assertTrue(u.is_active)

    def test_email_field_is_unique(self):
        from django.db import IntegrityError
        User.objects.create_user(
            username='first', email='dup@example.com', password='pass'
        )
        with self.assertRaises(IntegrityError):
            User.objects.create_user(
                username='second', email='dup@example.com', password='pass'
            )


class APIKeyGenerateTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='keyowner', email='keyowner@example.com', password='pass',
            email_verified=True,
        )

    def test_generate_creates_persisted_key(self):
        api_key = APIKey.generate(self.user, name='Test')
        self.assertIsNotNone(api_key.pk)
        self.assertTrue(APIKey.objects.filter(pk=api_key.pk).exists())

    def test_key_is_64_hex_chars(self):
        api_key = APIKey.generate(self.user)
        self.assertEqual(len(api_key.key), 64)
        self.assertRegex(api_key.key, r'^[0-9a-f]{64}$')

    def test_generate_associates_with_user(self):
        api_key = APIKey.generate(self.user, name='Mobile')
        self.assertEqual(api_key.user, self.user)

    def test_generate_sets_name(self):
        api_key = APIKey.generate(self.user, name='My Phone')
        self.assertEqual(api_key.name, 'My Phone')

    def test_generate_is_active_by_default(self):
        api_key = APIKey.generate(self.user)
        self.assertTrue(api_key.is_active)

    def test_generate_successive_keys_are_unique(self):
        k1 = APIKey.generate(self.user)
        k2 = APIKey.generate(self.user)
        self.assertNotEqual(k1.key, k2.key)

    def test_str_with_name(self):
        api_key = APIKey.generate(self.user, name='Android')
        self.assertIn('Android', str(api_key))
        self.assertIn(self.user.username, str(api_key))

    def test_str_without_name(self):
        api_key = APIKey.generate(self.user, name='')
        self.assertIn('Unnamed', str(api_key))
