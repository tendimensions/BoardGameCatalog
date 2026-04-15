"""
Unit tests for catalog serializers.
"""
from django.test import TestCase
from django.db.models import Value
from django.db.models.functions import Coalesce

from accounts.models import User
from catalog.models import Game, GameList, GameListEntry, UserCollection
from catalog.serializers import (
    CollectionItemSerializer,
    GameListDetailSerializer,
    GameListEntrySerializer,
    GameListSerializer,
    GameSerializer,
)


def _make_game(**kwargs):
    defaults = {
        'title': 'Catan',
        'bgg_id': 13,
        'year_published': 1995,
        'min_players': 3,
        'max_players': 4,
        'playing_time': 90,
        'thumbnail_url': 'https://example.com/thumb.jpg',
        'image_url': 'https://example.com/image.jpg',
    }
    defaults.update(kwargs)
    return Game.objects.create(**defaults)


def _make_user():
    return User.objects.create_user(
        username='serialtest', email='serial@example.com', password='pass'
    )


class GameSerializerTests(TestCase):
    def setUp(self):
        self.game = _make_game()

    def test_contains_expected_fields(self):
        data = GameSerializer(self.game).data
        expected = {
            'id', 'bgg_id', 'upc', 'title', 'year_published',
            'min_players', 'max_players', 'playing_time',
            'thumbnail_url', 'image_url', 'players_display', 'play_time_display',
        }
        self.assertEqual(set(data.keys()), expected)

    def test_players_display_included(self):
        data = GameSerializer(self.game).data
        self.assertIn('players_display', data)
        self.assertIsNotNone(data['players_display'])

    def test_play_time_display_included(self):
        data = GameSerializer(self.game).data
        self.assertIn('play_time_display', data)
        self.assertEqual(data['play_time_display'], '90 min')

    def test_title_serialized(self):
        data = GameSerializer(self.game).data
        self.assertEqual(data['title'], 'Catan')

    def test_null_year_serialized(self):
        game = _make_game(title='Timeless', bgg_id=999, year_published=None)
        data = GameSerializer(game).data
        self.assertIsNone(data['year_published'])


class CollectionItemSerializerTests(TestCase):
    def setUp(self):
        self.user = _make_user()
        self.game = _make_game()
        self.item = UserCollection.objects.create(
            user=self.user,
            game=self.game,
            source=UserCollection.SOURCE_BGG,
        )

    def test_contains_expected_fields(self):
        data = CollectionItemSerializer(self.item).data
        self.assertIn('id', data)
        self.assertIn('game', data)
        self.assertIn('source', data)
        self.assertIn('is_lent', data)

    def test_game_is_nested(self):
        data = CollectionItemSerializer(self.item).data
        self.assertIsInstance(data['game'], dict)
        self.assertEqual(data['game']['title'], 'Catan')

    def test_source_reflected(self):
        data = CollectionItemSerializer(self.item).data
        self.assertEqual(data['source'], UserCollection.SOURCE_BGG)


class GameListSerializerTests(TestCase):
    def setUp(self):
        self.user = _make_user()

    def test_contains_expected_fields(self):
        # GameList.entry_count is a @property — no annotation needed.
        # GameListSerializer reads it directly from the model instance.
        gl = GameList.objects.create(user=self.user, name='My List')
        data = GameListSerializer(gl).data
        self.assertIn('id', data)
        self.assertIn('name', data)
        self.assertIn('description', data)
        self.assertIn('entry_count', data)
        self.assertIn('created_at', data)
        self.assertIn('updated_at', data)

    def test_entry_count_zero(self):
        gl = GameList.objects.create(user=self.user, name='Empty')
        data = GameListSerializer(gl).data
        self.assertEqual(data['entry_count'], 0)

    def test_entry_count_after_adding(self):
        game = _make_game(title='Game X', bgg_id=42)
        gl = GameList.objects.create(user=self.user, name='With Game')
        GameListEntry.objects.create(game_list=gl, game=game)
        data = GameListSerializer(gl).data
        self.assertEqual(data['entry_count'], 1)


class GameListEntrySerializerTests(TestCase):
    def setUp(self):
        self.user = _make_user()
        self.game = _make_game()
        self.gl = GameList.objects.create(user=self.user, name='Test List')
        self.entry = GameListEntry.objects.create(
            game_list=self.gl,
            game=self.game,
            note='My note',
            added_via=GameListEntry.VIA_BARCODE,
        )

    def test_contains_expected_fields(self):
        data = GameListEntrySerializer(self.entry).data
        self.assertIn('id', data)
        self.assertIn('game', data)
        self.assertIn('note', data)
        self.assertIn('added_via', data)
        self.assertIn('created_at', data)
        self.assertIn('updated_at', data)

    def test_game_is_nested(self):
        data = GameListEntrySerializer(self.entry).data
        self.assertIsInstance(data['game'], dict)
        self.assertEqual(data['game']['title'], 'Catan')

    def test_note_serialized(self):
        data = GameListEntrySerializer(self.entry).data
        self.assertEqual(data['note'], 'My note')

    def test_added_via_serialized(self):
        data = GameListEntrySerializer(self.entry).data
        self.assertEqual(data['added_via'], GameListEntry.VIA_BARCODE)


class GameListDetailSerializerTests(TestCase):
    def setUp(self):
        self.user = _make_user()
        self.game = _make_game()
        self.gl = GameList.objects.create(user=self.user, name='Detail List')
        self.entry = GameListEntry.objects.create(game_list=self.gl, game=self.game)

    def test_includes_entries(self):
        data = GameListDetailSerializer(self.gl).data
        self.assertIn('entries', data)
        self.assertEqual(len(data['entries']), 1)

    def test_entry_has_nested_game(self):
        data = GameListDetailSerializer(self.gl).data
        entry_data = data['entries'][0]
        self.assertIn('game', entry_data)
        self.assertEqual(entry_data['game']['title'], 'Catan')
