"""
Unit tests for accounts forms: RegistrationForm, ProfileEditForm, APIKeyNameForm.
"""
from django.test import TestCase

from accounts.forms import APIKeyNameForm, ProfileEditForm, RegistrationForm
from accounts.models import User


def _valid_reg_data(**overrides):
    data = {
        'username': 'newuser',
        'email': 'new@example.com',
        'bgg_username': '',
        'password1': 'ValidPass!99',
        'password2': 'ValidPass!99',
        'terms': True,
    }
    data.update(overrides)
    return data


class RegistrationFormTests(TestCase):
    def test_valid_data_is_valid(self):
        form = RegistrationForm(data=_valid_reg_data())
        self.assertTrue(form.is_valid(), form.errors)

    def test_save_sets_is_active_false(self):
        form = RegistrationForm(data=_valid_reg_data())
        self.assertTrue(form.is_valid())
        user = form.save()
        self.assertFalse(user.is_active)

    def test_save_persists_bgg_username(self):
        form = RegistrationForm(data=_valid_reg_data(bgg_username='BoardGameFan'))
        self.assertTrue(form.is_valid())
        user = form.save()
        self.assertEqual(user.bgg_username, 'BoardGameFan')

    def test_bgg_username_optional(self):
        form = RegistrationForm(data=_valid_reg_data(bgg_username=''))
        self.assertTrue(form.is_valid())

    def test_terms_required(self):
        form = RegistrationForm(data=_valid_reg_data(terms=False))
        self.assertFalse(form.is_valid())
        self.assertIn('terms', form.errors)

    def test_duplicate_email_case_insensitive(self):
        User.objects.create_user(
            username='existing', email='taken@example.com', password='pass'
        )
        form = RegistrationForm(data=_valid_reg_data(email='TAKEN@EXAMPLE.COM'))
        self.assertFalse(form.is_valid())
        self.assertIn('email', form.errors)

    def test_duplicate_email_exact_match(self):
        User.objects.create_user(
            username='existing', email='taken@example.com', password='pass'
        )
        form = RegistrationForm(data=_valid_reg_data(email='taken@example.com'))
        self.assertFalse(form.is_valid())
        self.assertIn('email', form.errors)

    def test_duplicate_username_case_insensitive(self):
        User.objects.create_user(
            username='ExistingUser', email='other@example.com', password='pass'
        )
        form = RegistrationForm(data=_valid_reg_data(username='existinguser'))
        self.assertFalse(form.is_valid())
        self.assertIn('username', form.errors)

    def test_duplicate_username_exact_match(self):
        User.objects.create_user(
            username='taken', email='other@example.com', password='pass'
        )
        form = RegistrationForm(data=_valid_reg_data(username='taken'))
        self.assertFalse(form.is_valid())
        self.assertIn('username', form.errors)

    def test_email_stored_lowercase(self):
        form = RegistrationForm(data=_valid_reg_data(email='Mixed@EXAMPLE.COM'))
        self.assertTrue(form.is_valid())
        user = form.save()
        self.assertEqual(user.email, 'mixed@example.com')

    def test_password_mismatch_invalid(self):
        form = RegistrationForm(
            data=_valid_reg_data(password1='ValidPass!99', password2='Different!99')
        )
        self.assertFalse(form.is_valid())


class ProfileEditFormTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='editme', email='editme@example.com', password='pass'
        )
        self.other = User.objects.create_user(
            username='otherguy', email='other@example.com', password='pass'
        )

    def test_same_username_is_valid(self):
        """Saving own username should not trigger uniqueness error."""
        form = ProfileEditForm(data={'username': 'editme'}, instance=self.user)
        self.assertTrue(form.is_valid(), form.errors)

    def test_duplicate_username_from_other_user(self):
        form = ProfileEditForm(data={'username': 'otherguy'}, instance=self.user)
        self.assertFalse(form.is_valid())
        self.assertIn('username', form.errors)

    def test_duplicate_case_insensitive(self):
        form = ProfileEditForm(data={'username': 'OTHERGUY'}, instance=self.user)
        self.assertFalse(form.is_valid())
        self.assertIn('username', form.errors)

    def test_new_unique_username_valid(self):
        form = ProfileEditForm(data={'username': 'brandnewname'}, instance=self.user)
        self.assertTrue(form.is_valid(), form.errors)


class APIKeyNameFormTests(TestCase):
    def test_name_optional(self):
        form = APIKeyNameForm(data={'name': ''})
        self.assertTrue(form.is_valid())

    def test_name_accepted(self):
        form = APIKeyNameForm(data={'name': 'My Android Phone'})
        self.assertTrue(form.is_valid())

    def test_name_max_100(self):
        form = APIKeyNameForm(data={'name': 'x' * 101})
        self.assertFalse(form.is_valid())
        self.assertIn('name', form.errors)

    def test_name_exactly_100_valid(self):
        form = APIKeyNameForm(data={'name': 'x' * 100})
        self.assertTrue(form.is_valid())
