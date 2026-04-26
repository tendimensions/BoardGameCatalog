"""
Unit tests for catalog.gameupc module.

Network-calling functions (lookup_barcode, submit_barcode_mapping) are tested
via mocks so no real HTTP requests are made.  The _base_url, _api_key, and
_int_or_none helpers are pure and testable directly.
"""
import hashlib
from unittest.mock import MagicMock, patch

from django.test import TestCase, override_settings

from catalog.gameupc import (
    GameNotFound,
    GameUPCError,
    _api_key,
    _base_url,
    _int_or_none,
    lookup_barcode,
    submit_barcode_mapping,
)


# ── _int_or_none ──────────────────────────────────────────────────────────────

class IntOrNoneTests(TestCase):
    def test_positive_int(self):
        self.assertEqual(_int_or_none(5), 5)

    def test_positive_string(self):
        self.assertEqual(_int_or_none('10'), 10)

    def test_zero_returns_none(self):
        self.assertIsNone(_int_or_none(0))

    def test_negative_returns_none(self):
        self.assertIsNone(_int_or_none(-3))

    def test_none_input_returns_none(self):
        self.assertIsNone(_int_or_none(None))

    def test_non_numeric_string_returns_none(self):
        self.assertIsNone(_int_or_none('abc'))


# ── _base_url and _api_key ────────────────────────────────────────────────────

class BaseUrlTests(TestCase):
    @override_settings(GAMEUPC_API_KEY='')
    def test_no_key_returns_test_url(self):
        self.assertIn('/test', _base_url())

    @override_settings(GAMEUPC_API_KEY='CHANGE-ME')
    def test_change_me_returns_test_url(self):
        self.assertIn('/test', _base_url())

    @override_settings(GAMEUPC_API_KEY='real-production-key-here')
    def test_real_key_returns_prod_url(self):
        url = _base_url()
        self.assertNotIn('/test', url)
        self.assertIn('gameupc.com', url)


class ApiKeyTests(TestCase):
    @override_settings(GAMEUPC_API_KEY='')
    def test_no_key_returns_test_key(self):
        self.assertEqual(_api_key(), 'test_test_test_test_test')

    @override_settings(GAMEUPC_API_KEY='CHANGE-ME')
    def test_change_me_returns_test_key(self):
        self.assertEqual(_api_key(), 'test_test_test_test_test')

    @override_settings(GAMEUPC_API_KEY='my-real-key-123')
    def test_real_key_returned_directly(self):
        self.assertEqual(_api_key(), 'my-real-key-123')


# ── lookup_barcode ────────────────────────────────────────────────────────────

def _mock_response(status_code=200, json_data=None):
    mock = MagicMock()
    mock.status_code = status_code
    mock.json.return_value = json_data or {}
    return mock


_VALID_BGG_INFO = [{
    'name': 'Catan',
    'bgg_id': 13,
    'year_published': 1995,
    'min_players': 3,
    'max_players': 4,
    'playing_time': 90,
    'thumbnail': 'https://example.com/thumb.jpg',
    'image': 'https://example.com/image.jpg',
}]


class LookupBarcodeTests(TestCase):
    @patch('catalog.gameupc.requests.get')
    def test_success_returns_result(self, mock_get):
        mock_get.return_value = _mock_response(
            200, {'new': False, 'bgg_info': _VALID_BGG_INFO}
        )
        result = lookup_barcode('0123456789012')
        self.assertEqual(result.upc, '0123456789012')
        self.assertEqual(result.title, 'Catan')
        self.assertEqual(result.bgg_id, 13)
        self.assertEqual(result.year_published, 1995)
        self.assertEqual(result.min_players, 3)
        self.assertEqual(result.max_players, 4)
        self.assertEqual(result.playing_time, 90)

    @patch('catalog.gameupc.requests.get')
    def test_404_raises_game_not_found(self, mock_get):
        mock_get.return_value = _mock_response(404)
        with self.assertRaises(GameNotFound):
            lookup_barcode('9999999999999')

    @patch('catalog.gameupc.requests.get')
    def test_new_true_raises_game_not_found(self, mock_get):
        mock_get.return_value = _mock_response(200, {'new': True, 'bgg_info': []})
        with self.assertRaises(GameNotFound):
            lookup_barcode('1111111111117')

    @patch('catalog.gameupc.requests.get')
    def test_empty_bgg_info_raises_game_not_found(self, mock_get):
        mock_get.return_value = _mock_response(200, {'new': False, 'bgg_info': []})
        with self.assertRaises(GameNotFound):
            lookup_barcode('1111111111117')

    @patch('catalog.gameupc.requests.get')
    def test_missing_bgg_info_key_raises_game_not_found(self, mock_get):
        mock_get.return_value = _mock_response(200, {'new': False})
        with self.assertRaises(GameNotFound):
            lookup_barcode('1111111111117')

    @patch('catalog.gameupc.requests.get')
    def test_500_error_raises_gameupc_error(self, mock_get):
        mock_get.return_value = _mock_response(500)
        with self.assertRaises(GameUPCError):
            lookup_barcode('0123456789012')

    @patch('catalog.gameupc.requests.get')
    def test_network_error_raises_gameupc_error(self, mock_get):
        import requests as req_lib
        mock_get.side_effect = req_lib.RequestException('timeout')
        with self.assertRaises(GameUPCError):
            lookup_barcode('0123456789012')

    @patch('catalog.gameupc.requests.get')
    def test_null_optional_fields_return_none(self, mock_get):
        """Fields absent from API response should default to None."""
        bgg_info = [{'name': 'Mystery Game', 'bgg_id': 999}]
        mock_get.return_value = _mock_response(200, {'new': False, 'bgg_info': bgg_info})
        result = lookup_barcode('0000000000000')
        self.assertIsNone(result.year_published)
        self.assertIsNone(result.min_players)
        self.assertIsNone(result.playing_time)
        self.assertEqual(result.thumbnail_url, '')
        self.assertEqual(result.image_url, '')

    @patch('catalog.gameupc.requests.get')
    def test_uses_x_api_key_header(self, mock_get):
        mock_get.return_value = _mock_response(
            200, {'new': False, 'bgg_info': _VALID_BGG_INFO}
        )
        lookup_barcode('0123456789012')
        call_kwargs = mock_get.call_args
        headers = call_kwargs[1].get('headers') or call_kwargs[0][1] if len(call_kwargs[0]) > 1 else {}
        # The headers are passed as a keyword argument
        headers = mock_get.call_args.kwargs.get('headers', mock_get.call_args.args[1] if len(mock_get.call_args.args) > 1 else {})
        self.assertIn('x-api-key', headers)


# ── submit_barcode_mapping ────────────────────────────────────────────────────

class SubmitBarcodeMappingTests(TestCase):
    @patch('catalog.gameupc.requests.post')
    def test_200_returns_true(self, mock_post):
        mock_post.return_value = _mock_response(200)
        result = submit_barcode_mapping('0123456789012', 13, user_id=42)
        self.assertTrue(result)

    @patch('catalog.gameupc.requests.post')
    def test_201_returns_true(self, mock_post):
        mock_post.return_value = _mock_response(201)
        result = submit_barcode_mapping('0123456789012', 13, user_id=42)
        self.assertTrue(result)

    @patch('catalog.gameupc.requests.post')
    def test_400_returns_false(self, mock_post):
        mock_post.return_value = _mock_response(400)
        result = submit_barcode_mapping('0123456789012', 13, user_id=42)
        self.assertFalse(result)

    @patch('catalog.gameupc.requests.post')
    def test_network_error_returns_false(self, mock_post):
        import requests as req_lib
        mock_post.side_effect = req_lib.RequestException('connection reset')
        result = submit_barcode_mapping('0123456789012', 13, user_id=42)
        self.assertFalse(result)

    @patch('catalog.gameupc.requests.post')
    def test_user_id_is_hashed(self, mock_post):
        """user_id must be SHA-256 hashed before being sent (REQ-CM-036)."""
        mock_post.return_value = _mock_response(200)
        submit_barcode_mapping('0123456789012', 13, user_id=99)

        call_kwargs = mock_post.call_args.kwargs
        json_body = call_kwargs.get('json', {})
        sent_id = json_body.get('user_id', '')

        expected = hashlib.sha256(b'99').hexdigest()
        self.assertEqual(sent_id, expected)
        # Original id must not appear in the request
        self.assertNotIn('99', sent_id)

    @patch('catalog.gameupc.requests.post')
    def test_correct_endpoint_called(self, mock_post):
        mock_post.return_value = _mock_response(200)
        submit_barcode_mapping('012345', 9999, user_id=1)
        called_url = mock_post.call_args.args[0]
        self.assertIn('012345', called_url)
        self.assertIn('9999', called_url)
