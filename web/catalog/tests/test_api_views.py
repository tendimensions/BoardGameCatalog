"""
Unit tests for catalog API views (REST endpoints consumed by the mobile app).
All tests use DRF's APIClient with a valid Bearer token.
External service calls (GameUPC) are mocked.
"""
from unittest.mock import MagicMock, patch

from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from accounts.models import APIKey, User
from catalog.gameupc import GameNotFound, GameUPCError, GameUPCResult
from catalog.models import Game, GameList, GameListEntry, UnlinkedBarcode, UserCollection


# ── Shared helpers ────────────────────────────────────────────────────────────

def _make_user(username='apiuser', email=None, verified=True, active=True,
               password='testpass123', **kwargs):
    email = email or f'{username}@example.com'
    u = User.objects.create_user(
        username=username, email=email, password=password,
        email_verified=verified, is_active=active, **kwargs
    )
    return u


def _make_game(title='Catan', bgg_id=13, **kwargs):
    return Game.objects.create(title=title, bgg_id=bgg_id, **kwargs)


def _gameupc_result(upc='012345678901', title='Catan', bgg_id=13):
    return GameUPCResult(
        upc=upc, title=title, bgg_id=bgg_id,
        year_published=1995, min_players=3, max_players=4,
        playing_time=90,
        thumbnail_url='https://example.com/thumb.jpg',
        image_url='https://example.com/image.jpg',
    )


class ApiTestCase(TestCase):
    """Base class: creates a verified user and sets up APIClient with Bearer auth."""

    def setUp(self):
        self.user = _make_user()
        self.api_key = APIKey.generate(self.user, name='Test')
        self.client = APIClient()
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.api_key.key}')


# ── LoginView ────────────────────────────────────────────────────────────────

class LoginViewTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = _make_user(username='loginuser', password='correctpass')

    def _post(self, **body):
        return self.client.post('/api/v1/auth/login', body, format='json')

    def test_missing_username_returns_400(self):
        resp = self._post(password='correctpass')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

    def test_missing_password_returns_400(self):
        resp = self._post(username='loginuser')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

    def test_wrong_password_returns_401(self):
        resp = self._post(username='loginuser', password='wrong')
        self.assertEqual(resp.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_unverified_email_returns_403(self):
        self.user.email_verified = False
        self.user.save()
        resp = self._post(username='loginuser', password='correctpass')
        self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)

    def test_valid_credentials_returns_200_with_key(self):
        resp = self._post(username='loginuser', password='correctpass')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertIn('api_key', resp.data)
        self.assertIn('user', resp.data)
        self.assertEqual(resp.data['user']['username'], 'loginuser')

    def test_second_login_returns_same_mobile_key(self):
        resp1 = self._post(username='loginuser', password='correctpass')
        resp2 = self._post(username='loginuser', password='correctpass')
        self.assertEqual(resp1.data['api_key'], resp2.data['api_key'])

    def test_login_creates_mobile_named_key(self):
        self._post(username='loginuser', password='correctpass')
        self.assertTrue(
            APIKey.objects.filter(user=self.user, name='Mobile').exists()
        )


# ── UserProfileView ───────────────────────────────────────────────────────────

class UserProfileViewTests(ApiTestCase):
    def test_authenticated_returns_200(self):
        resp = self.client.get('/api/v1/users/profile')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)

    def test_returns_correct_user_data(self):
        resp = self.client.get('/api/v1/users/profile')
        self.assertEqual(resp.data['username'], self.user.username)
        self.assertEqual(resp.data['email'], self.user.email)

    def test_unauthenticated_returns_401(self):
        # DRF with token-based auth returns 401 (not 403) for missing credentials.
        client = APIClient()
        resp = client.get('/api/v1/users/profile')
        self.assertEqual(resp.status_code, status.HTTP_401_UNAUTHORIZED)


# ── APICollectionView ─────────────────────────────────────────────────────────

class APICollectionViewTests(ApiTestCase):
    def setUp(self):
        super().setUp()
        self.game1 = _make_game(title='Agricola', bgg_id=31260)
        self.game2 = _make_game(title='Wingspan', bgg_id=266192)
        UserCollection.objects.create(user=self.user, game=self.game1)
        UserCollection.objects.create(user=self.user, game=self.game2)

    def test_returns_200(self):
        resp = self.client.get('/api/v1/collection')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)

    def test_returns_user_games(self):
        resp = self.client.get('/api/v1/collection')
        self.assertEqual(resp.data['total_count'], 2)

    def test_empty_collection(self):
        other = _make_user(username='other', email='other@example.com')
        key = APIKey.generate(other, name='Test')
        c = APIClient()
        c.credentials(HTTP_AUTHORIZATION=f'Bearer {key.key}')
        resp = c.get('/api/v1/collection')
        self.assertEqual(resp.data['total_count'], 0)
        self.assertEqual(resp.data['games'], [])

    def test_search_filter(self):
        resp = self.client.get('/api/v1/collection?q=wing')
        self.assertEqual(resp.data['total_count'], 1)
        self.assertEqual(resp.data['games'][0]['game']['title'], 'Wingspan')

    def test_limit_respected(self):
        resp = self.client.get('/api/v1/collection?limit=1')
        self.assertEqual(resp.data['limit'], 1)
        self.assertEqual(len(resp.data['games']), 1)

    def test_limit_max_200(self):
        resp = self.client.get('/api/v1/collection?limit=9999')
        self.assertEqual(resp.data['limit'], 200)

    def test_offset(self):
        resp = self.client.get('/api/v1/collection?offset=1&sort=title')
        self.assertEqual(resp.data['offset'], 1)
        self.assertEqual(len(resp.data['games']), 1)

    def test_other_user_cannot_see_collection(self):
        other = _make_user(username='other2', email='other2@example.com')
        key = APIKey.generate(other, name='Test')
        c = APIClient()
        c.credentials(HTTP_AUTHORIZATION=f'Bearer {key.key}')
        resp = c.get('/api/v1/collection')
        self.assertEqual(resp.data['total_count'], 0)


# ── BarcodeScanView ───────────────────────────────────────────────────────────

class BarcodeScanViewTests(ApiTestCase):
    UPC = '012345678901'

    def _post(self, **body):
        return self.client.post('/api/v1/scan/barcode', body, format='json')

    def test_missing_upc_returns_400(self):
        resp = self._post()
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

    @patch('catalog.api_views.gameupc_client.lookup_barcode')
    def test_game_not_found_creates_unlinked_barcode(self, mock_lookup):
        mock_lookup.side_effect = GameNotFound('not found')
        resp = self._post(upc=self.UPC)
        self.assertEqual(resp.status_code, status.HTTP_404_NOT_FOUND)
        self.assertTrue(UnlinkedBarcode.objects.filter(user=self.user, upc=self.UPC).exists())
        self.assertTrue(resp.data.get('awaiting_link'))

    @patch('catalog.api_views.gameupc_client.lookup_barcode')
    def test_game_not_found_second_scan_updates_not_duplicates(self, mock_lookup):
        mock_lookup.side_effect = GameNotFound('not found')
        self._post(upc=self.UPC)
        self._post(upc=self.UPC)
        self.assertEqual(UnlinkedBarcode.objects.filter(user=self.user, upc=self.UPC).count(), 1)

    @patch('catalog.api_views.gameupc_client.lookup_barcode')
    def test_service_unavailable_returns_503(self, mock_lookup):
        mock_lookup.side_effect = GameUPCError('timeout')
        resp = self._post(upc=self.UPC)
        self.assertEqual(resp.status_code, status.HTTP_503_SERVICE_UNAVAILABLE)

    @patch('catalog.api_views.gameupc_client.lookup_barcode')
    def test_new_game_creates_collection_entry_returns_201(self, mock_lookup):
        mock_lookup.return_value = _gameupc_result(upc=self.UPC)
        resp = self._post(upc=self.UPC)
        self.assertEqual(resp.status_code, status.HTTP_201_CREATED)
        self.assertTrue(resp.data['added_to_collection'])
        self.assertTrue(Game.objects.filter(upc=self.UPC).exists())
        self.assertTrue(UserCollection.objects.filter(user=self.user).exists())

    @patch('catalog.api_views.gameupc_client.lookup_barcode')
    def test_existing_game_in_collection_returns_200(self, mock_lookup):
        game = _make_game(title='Catan', bgg_id=13, upc=self.UPC)
        UserCollection.objects.create(user=self.user, game=game)
        mock_lookup.return_value = _gameupc_result(upc=self.UPC)
        resp = self._post(upc=self.UPC)
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertFalse(resp.data['added_to_collection'])

    @patch('catalog.api_views.gameupc_client.lookup_barcode')
    def test_title_match_stamps_upc(self, mock_lookup):
        """Game already in DB via BGG sync (no UPC) — scan should stamp the UPC."""
        game = _make_game(title='Catan', bgg_id=13, upc='')
        mock_lookup.return_value = _gameupc_result(upc=self.UPC, title='Catan')
        self._post(upc=self.UPC)
        game.refresh_from_db()
        self.assertEqual(game.upc, self.UPC)

    @patch('catalog.api_views.gameupc_client.lookup_barcode')
    def test_mode_b_adds_game_to_list(self, mock_lookup):
        mock_lookup.return_value = _gameupc_result(upc=self.UPC)
        gl = GameList.objects.create(user=self.user, name='Weekend')
        resp = self._post(upc=self.UPC, list_id=gl.id)
        self.assertEqual(resp.status_code, status.HTTP_201_CREATED)
        self.assertTrue(resp.data.get('added_to_list'))
        self.assertFalse(resp.data.get('already_on_list'))
        self.assertTrue(GameListEntry.objects.filter(game_list=gl).exists())

    @patch('catalog.api_views.gameupc_client.lookup_barcode')
    def test_mode_b_already_on_list(self, mock_lookup):
        game = _make_game(upc=self.UPC, bgg_id=None)
        UserCollection.objects.create(user=self.user, game=game)
        gl = GameList.objects.create(user=self.user, name='Weekend')
        GameListEntry.objects.create(game_list=gl, game=game)
        mock_lookup.return_value = _gameupc_result(upc=self.UPC)
        resp = self._post(upc=self.UPC, list_id=gl.id)
        self.assertTrue(resp.data.get('already_on_list'))

    @patch('catalog.api_views.gameupc_client.lookup_barcode')
    def test_mode_b_invalid_list_returns_404(self, mock_lookup):
        mock_lookup.return_value = _gameupc_result(upc=self.UPC)
        resp = self._post(upc=self.UPC, list_id=99999)
        self.assertEqual(resp.status_code, status.HTTP_404_NOT_FOUND)

    @patch('catalog.api_views.gameupc_client.lookup_barcode')
    def test_mode_b_cannot_use_other_users_list(self, mock_lookup):
        mock_lookup.return_value = _gameupc_result(upc=self.UPC)
        other = _make_user(username='oth', email='oth@example.com')
        gl = GameList.objects.create(user=other, name='Theirs')
        resp = self._post(upc=self.UPC, list_id=gl.id)
        self.assertEqual(resp.status_code, status.HTTP_404_NOT_FOUND)


# ── LinkBarcodeView ───────────────────────────────────────────────────────────

class LinkBarcodeViewTests(ApiTestCase):
    UPC = '999888777666'

    def setUp(self):
        super().setUp()
        self.game = _make_game(title='Pandemic', bgg_id=30549, upc='')
        UserCollection.objects.create(user=self.user, game=self.game)
        UnlinkedBarcode.objects.create(user=self.user, upc=self.UPC)

    def _post(self, **body):
        return self.client.post('/api/v1/scan/link', body, format='json')

    def test_missing_fields_returns_400(self):
        resp = self._post(upc=self.UPC)
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

    def test_unlinked_barcode_not_found_returns_404(self):
        resp = self._post(upc='doesnotexist', game_id=self.game.id)
        self.assertEqual(resp.status_code, status.HTTP_404_NOT_FOUND)

    def test_game_not_in_collection_returns_404(self):
        other_game = _make_game(title='Other', bgg_id=99999)
        resp = self._post(upc=self.UPC, game_id=other_game.id)
        self.assertEqual(resp.status_code, status.HTTP_404_NOT_FOUND)

    def test_game_already_has_upc_returns_409(self):
        self.game.upc = 'existing-upc'
        self.game.save()
        resp = self._post(upc=self.UPC, game_id=self.game.id)
        self.assertEqual(resp.status_code, status.HTTP_409_CONFLICT)

    @patch('catalog.api_views.gameupc_client.submit_barcode_mapping')
    def test_success_stamps_upc_and_deletes_unlinked(self, mock_submit):
        mock_submit.return_value = True
        resp = self._post(upc=self.UPC, game_id=self.game.id)
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.game.refresh_from_db()
        self.assertEqual(self.game.upc, self.UPC)
        self.assertFalse(UnlinkedBarcode.objects.filter(user=self.user, upc=self.UPC).exists())

    @patch('catalog.api_views.gameupc_client.submit_barcode_mapping')
    def test_submits_to_gameupc_when_bgg_id_present(self, mock_submit):
        mock_submit.return_value = True
        self._post(upc=self.UPC, game_id=self.game.id)
        mock_submit.assert_called_once_with(self.UPC, self.game.bgg_id, self.user.id)

    @patch('catalog.api_views.gameupc_client.submit_barcode_mapping')
    def test_skips_gameupc_when_no_bgg_id(self, mock_submit):
        self.game.bgg_id = None
        self.game.save()
        resp = self._post(upc=self.UPC, game_id=self.game.id)
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        mock_submit.assert_not_called()
        self.assertFalse(resp.data['submitted_to_gameupc'])


# ── DiscardBarcodeView ────────────────────────────────────────────────────────

class DiscardBarcodeViewTests(ApiTestCase):
    UPC = '111222333444'

    def test_deletes_unlinked_barcode(self):
        UnlinkedBarcode.objects.create(user=self.user, upc=self.UPC)
        resp = self.client.delete(f'/api/v1/scan/unlinked/{self.UPC}')
        self.assertEqual(resp.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(UnlinkedBarcode.objects.filter(user=self.user, upc=self.UPC).exists())

    def test_silent_no_op_if_not_found(self):
        resp = self.client.delete(f'/api/v1/scan/unlinked/notexist')
        self.assertEqual(resp.status_code, status.HTTP_204_NO_CONTENT)

    def test_only_deletes_own_barcode(self):
        other = _make_user(username='disc_other', email='disc@example.com')
        UnlinkedBarcode.objects.create(user=other, upc=self.UPC)
        self.client.delete(f'/api/v1/scan/unlinked/{self.UPC}')
        # Other user's barcode should remain
        self.assertTrue(UnlinkedBarcode.objects.filter(user=other, upc=self.UPC).exists())


# ── GameListsView ─────────────────────────────────────────────────────────────

class GameListsViewTests(ApiTestCase):
    def test_get_returns_empty_list(self):
        resp = self.client.get('/api/v1/lists')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(resp.data, [])

    def test_get_returns_user_lists(self):
        GameList.objects.create(user=self.user, name='Party Games')
        resp = self.client.get('/api/v1/lists')
        self.assertEqual(len(resp.data), 1)
        self.assertEqual(resp.data[0]['name'], 'Party Games')

    def test_get_does_not_return_other_users_lists(self):
        other = _make_user(username='lists_other', email='lother@example.com')
        GameList.objects.create(user=other, name='Theirs')
        resp = self.client.get('/api/v1/lists')
        self.assertEqual(len(resp.data), 0)

    def test_post_creates_list(self):
        resp = self.client.post('/api/v1/lists', {'name': 'New List'}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_201_CREATED)
        self.assertEqual(resp.data['name'], 'New List')
        self.assertTrue(GameList.objects.filter(user=self.user, name='New List').exists())

    def test_post_name_required(self):
        resp = self.client.post('/api/v1/lists', {'name': ''}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

    def test_post_with_description(self):
        resp = self.client.post(
            '/api/v1/lists',
            {'name': 'Coops', 'description': 'Co-operative games'},
            format='json',
        )
        self.assertEqual(resp.status_code, status.HTTP_201_CREATED)
        self.assertEqual(resp.data['description'], 'Co-operative games')


# ── GameListDetailView ────────────────────────────────────────────────────────

class GameListDetailViewTests(ApiTestCase):
    def setUp(self):
        super().setUp()
        self.gl = GameList.objects.create(user=self.user, name='Detail List')
        self.game = _make_game(title='Azul', bgg_id=230802)
        self.entry = GameListEntry.objects.create(game_list=self.gl, game=self.game)

    def test_get_returns_list_with_entries(self):
        resp = self.client.get(f'/api/v1/lists/{self.gl.id}')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(resp.data['name'], 'Detail List')
        self.assertEqual(len(resp.data['entries']), 1)

    def test_get_other_users_list_returns_404(self):
        other = _make_user(username='det_other', email='dother@example.com')
        gl2 = GameList.objects.create(user=other, name='Theirs')
        resp = self.client.get(f'/api/v1/lists/{gl2.id}')
        self.assertEqual(resp.status_code, status.HTTP_404_NOT_FOUND)

    def test_patch_updates_name(self):
        resp = self.client.patch(
            f'/api/v1/lists/{self.gl.id}', {'name': 'Renamed'}, format='json'
        )
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.gl.refresh_from_db()
        self.assertEqual(self.gl.name, 'Renamed')

    def test_patch_empty_name_returns_400(self):
        resp = self.client.patch(
            f'/api/v1/lists/{self.gl.id}', {'name': ''}, format='json'
        )
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

    def test_patch_updates_description(self):
        resp = self.client.patch(
            f'/api/v1/lists/{self.gl.id}', {'description': 'New desc'}, format='json'
        )
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.gl.refresh_from_db()
        self.assertEqual(self.gl.description, 'New desc')

    def test_delete_removes_list(self):
        resp = self.client.delete(f'/api/v1/lists/{self.gl.id}')
        self.assertEqual(resp.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(GameList.objects.filter(pk=self.gl.id).exists())

    def test_delete_cascades_entries(self):
        self.client.delete(f'/api/v1/lists/{self.gl.id}')
        self.assertFalse(GameListEntry.objects.filter(pk=self.entry.id).exists())


# ── GameListEntriesView ───────────────────────────────────────────────────────

class GameListEntriesViewTests(ApiTestCase):
    def setUp(self):
        super().setUp()
        self.gl = GameList.objects.create(user=self.user, name='Entry List')
        self.game = _make_game(title='Ticket to Ride', bgg_id=9209)
        UserCollection.objects.create(user=self.user, game=self.game)

    def _url(self):
        return f'/api/v1/lists/{self.gl.id}/entries'

    def test_post_adds_game_to_list(self):
        resp = self.client.post(self._url(), {'game_id': self.game.id}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_201_CREATED)
        self.assertTrue(GameListEntry.objects.filter(game_list=self.gl, game=self.game).exists())

    def test_game_not_in_collection_returns_404(self):
        other_game = _make_game(title='Unowned', bgg_id=99)
        resp = self.client.post(self._url(), {'game_id': other_game.id}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_404_NOT_FOUND)

    def test_duplicate_entry_returns_409(self):
        GameListEntry.objects.create(game_list=self.gl, game=self.game)
        resp = self.client.post(self._url(), {'game_id': self.game.id}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_409_CONFLICT)

    def test_missing_game_id_returns_400(self):
        resp = self.client.post(self._url(), {}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

    def test_with_note(self):
        resp = self.client.post(
            self._url(), {'game_id': self.game.id, 'note': 'Great game'}, format='json'
        )
        self.assertEqual(resp.status_code, status.HTTP_201_CREATED)
        self.assertEqual(resp.data['note'], 'Great game')


# ── GameListEntryDetailView ───────────────────────────────────────────────────

class GameListEntryDetailViewTests(ApiTestCase):
    def setUp(self):
        super().setUp()
        self.gl = GameList.objects.create(user=self.user, name='Entry Detail')
        self.game = _make_game(title='Splendor', bgg_id=148228)
        UserCollection.objects.create(user=self.user, game=self.game)
        self.entry = GameListEntry.objects.create(
            game_list=self.gl, game=self.game, note='original note'
        )

    def _url(self):
        return f'/api/v1/lists/{self.gl.id}/entries/{self.entry.id}'

    def test_patch_updates_note(self):
        resp = self.client.patch(self._url(), {'note': 'updated note'}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.entry.refresh_from_db()
        self.assertEqual(self.entry.note, 'updated note')

    def test_patch_clears_note(self):
        resp = self.client.patch(self._url(), {'note': ''}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.entry.refresh_from_db()
        self.assertEqual(self.entry.note, '')

    def test_patch_other_users_entry_returns_404(self):
        other = _make_user(username='entry_other', email='eother@example.com')
        key = APIKey.generate(other, name='Test')
        c = APIClient()
        c.credentials(HTTP_AUTHORIZATION=f'Bearer {key.key}')
        resp = c.patch(self._url(), {'note': 'hack'}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_404_NOT_FOUND)

    def test_delete_removes_entry(self):
        resp = self.client.delete(self._url())
        self.assertEqual(resp.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(GameListEntry.objects.filter(pk=self.entry.id).exists())

    def test_delete_nonexistent_returns_404(self):
        resp = self.client.delete(f'/api/v1/lists/{self.gl.id}/entries/99999')
        self.assertEqual(resp.status_code, status.HTTP_404_NOT_FOUND)
