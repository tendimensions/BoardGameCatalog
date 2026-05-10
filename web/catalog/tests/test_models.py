"""
Unit tests for catalog models:
  Game, UserCollection, GameList, GameListEntry, UnlinkedBarcode
"""
from django.db import IntegrityError
from django.test import TestCase

from accounts.models import User
from catalog.models import (
    Game,
    GameList,
    GameListEntry,
    GameRequest,
    LendingHistory,
    PartyList,
    PartyListGame,
    PartyListShare,
    UnlinkedBarcode,
    UserCollection,
)


def _make_user(username='testuser', email=None, **kwargs):
    email = email or f'{username}@example.com'
    return User.objects.create_user(username=username, email=email, password='pass', **kwargs)


def _make_game(title='Catan', bgg_id=None, **kwargs):
    return Game.objects.create(title=title, bgg_id=bgg_id, **kwargs)


# ── Game model ────────────────────────────────────────────────────────────────

class GameStrTests(TestCase):
    def test_str_with_year(self):
        g = _make_game(title='Catan', year_published=1995)
        self.assertEqual(str(g), 'Catan (1995)')

    def test_str_without_year(self):
        g = _make_game(title='Catan', year_published=None)
        self.assertEqual(str(g), 'Catan')


class GamePlayersDisplayTests(TestCase):
    def test_range(self):
        g = _make_game(min_players=2, max_players=5)
        self.assertEqual(g.players_display, '2\u20135')

    def test_exact(self):
        g = _make_game(min_players=4, max_players=4)
        self.assertEqual(g.players_display, '4')

    def test_min_only(self):
        g = _make_game(min_players=2, max_players=None)
        self.assertEqual(g.players_display, '2')

    def test_max_only(self):
        g = _make_game(min_players=None, max_players=6)
        self.assertEqual(g.players_display, '6')

    def test_neither(self):
        g = _make_game(min_players=None, max_players=None)
        self.assertEqual(g.players_display, '\u2014')


class GamePlayTimeDisplayTests(TestCase):
    def test_with_time(self):
        g = _make_game(playing_time=90)
        self.assertEqual(g.play_time_display, '90 min')

    def test_without_time(self):
        g = _make_game(playing_time=None)
        self.assertEqual(g.play_time_display, '\u2014')


class GameBggIdUniquenessTests(TestCase):
    def test_duplicate_bgg_id_raises(self):
        _make_game(bgg_id=1234)
        with self.assertRaises(IntegrityError):
            _make_game(title='Other Game', bgg_id=1234)

    def test_multiple_null_bgg_ids_allowed(self):
        """NULL bgg_id is not subject to uniqueness constraint."""
        _make_game(title='Game A', bgg_id=None)
        _make_game(title='Game B', bgg_id=None)  # should not raise


# ── UserCollection model ──────────────────────────────────────────────────────

class UserCollectionTests(TestCase):
    def setUp(self):
        self.user = _make_user()
        self.game = _make_game()

    def test_str(self):
        uc = UserCollection.objects.create(user=self.user, game=self.game)
        self.assertIn(self.user.username, str(uc))
        self.assertIn(self.game.title, str(uc))

    def test_default_source_is_manual(self):
        uc = UserCollection.objects.create(user=self.user, game=self.game)
        self.assertEqual(uc.source, UserCollection.SOURCE_MANUAL)

    def test_is_lent_defaults_false(self):
        uc = UserCollection.objects.create(user=self.user, game=self.game)
        self.assertFalse(uc.is_lent)

    def test_unique_together_user_game(self):
        UserCollection.objects.create(user=self.user, game=self.game)
        with self.assertRaises(IntegrityError):
            UserCollection.objects.create(user=self.user, game=self.game)

    def test_source_constants_defined(self):
        self.assertEqual(UserCollection.SOURCE_BGG, 'bgg_sync')
        self.assertEqual(UserCollection.SOURCE_MANUAL, 'manual')
        self.assertEqual(UserCollection.SOURCE_BARCODE, 'barcode')


# ── UnlinkedBarcode model ─────────────────────────────────────────────────────

class UnlinkedBarcodeTests(TestCase):
    def setUp(self):
        self.user = _make_user()

    def test_str(self):
        ub = UnlinkedBarcode.objects.create(user=self.user, upc='012345678901')
        self.assertIn('012345678901', str(ub))
        self.assertIn(self.user.username, str(ub))

    def test_unique_together_user_upc(self):
        UnlinkedBarcode.objects.create(user=self.user, upc='012345678901')
        with self.assertRaises(IntegrityError):
            UnlinkedBarcode.objects.create(user=self.user, upc='012345678901')

    def test_same_upc_different_users_allowed(self):
        user2 = _make_user(username='other', email='other@example.com')
        UnlinkedBarcode.objects.create(user=self.user, upc='012345678901')
        UnlinkedBarcode.objects.create(user=user2, upc='012345678901')  # no raise


# ── GameList model ────────────────────────────────────────────────────────────

class GameListTests(TestCase):
    def setUp(self):
        self.user = _make_user()
        self.game = _make_game()

    def test_str(self):
        gl = GameList.objects.create(user=self.user, name='Weekend Games')
        self.assertIn('Weekend Games', str(gl))
        self.assertIn(self.user.username, str(gl))

    def test_entry_count_zero(self):
        gl = GameList.objects.create(user=self.user, name='Empty')
        self.assertEqual(gl.entry_count, 0)

    def test_entry_count_after_adding(self):
        gl = GameList.objects.create(user=self.user, name='Not Empty')
        GameListEntry.objects.create(game_list=gl, game=self.game)
        self.assertEqual(gl.entry_count, 1)

    def test_description_blank_by_default(self):
        gl = GameList.objects.create(user=self.user, name='List')
        self.assertEqual(gl.description, '')


# ── GameListEntry model ───────────────────────────────────────────────────────

class GameListEntryTests(TestCase):
    def setUp(self):
        self.user = _make_user()
        self.game = _make_game()
        self.game2 = _make_game(title='Ticket to Ride', bgg_id=9209)
        self.gl = GameList.objects.create(user=self.user, name='My List')

    def test_str(self):
        entry = GameListEntry.objects.create(game_list=self.gl, game=self.game)
        self.assertIn(self.game.title, str(entry))
        self.assertIn(self.gl.name, str(entry))

    def test_default_added_via_is_manual(self):
        entry = GameListEntry.objects.create(game_list=self.gl, game=self.game)
        self.assertEqual(entry.added_via, GameListEntry.VIA_MANUAL)

    def test_note_blank_by_default(self):
        entry = GameListEntry.objects.create(game_list=self.gl, game=self.game)
        self.assertEqual(entry.note, '')

    def test_unique_together_game_list_game(self):
        GameListEntry.objects.create(game_list=self.gl, game=self.game)
        with self.assertRaises(IntegrityError):
            GameListEntry.objects.create(game_list=self.gl, game=self.game)

    def test_same_game_in_different_lists_allowed(self):
        gl2 = GameList.objects.create(user=self.user, name='Other List')
        GameListEntry.objects.create(game_list=self.gl, game=self.game)
        GameListEntry.objects.create(game_list=gl2, game=self.game)  # no raise

    def test_via_constants_defined(self):
        self.assertEqual(GameListEntry.VIA_MANUAL, 'manual')
        self.assertEqual(GameListEntry.VIA_BARCODE, 'barcode')


# ── PartyList model ───────────────────────────────────────────────────────────

class PartyListTests(TestCase):
    def setUp(self):
        self.user = _make_user()

    def test_str(self):
        party_list = PartyList.objects.create(owner=self.user, name='Game Night')
        self.assertEqual(str(party_list), 'Game Night (testuser)')

    def test_description_blank_by_default(self):
        party_list = PartyList.objects.create(owner=self.user, name='Game Night')
        self.assertEqual(party_list.description, '')

    def test_event_date_optional(self):
        party_list = PartyList.objects.create(owner=self.user, name='Game Night')
        self.assertIsNone(party_list.event_date)


class PartyListGameTests(TestCase):
    def setUp(self):
        self.user = _make_user()
        self.game = _make_game()
        self.party_list = PartyList.objects.create(owner=self.user, name='Weekend')

    def test_unique_together_party_list_game(self):
        PartyListGame.objects.create(party_list=self.party_list, game=self.game)
        with self.assertRaises(IntegrityError):
            PartyListGame.objects.create(party_list=self.party_list, game=self.game)

    def test_same_game_in_different_party_lists_allowed(self):
        other_party_list = PartyList.objects.create(owner=self.user, name='Holiday')
        PartyListGame.objects.create(party_list=self.party_list, game=self.game)
        PartyListGame.objects.create(party_list=other_party_list, game=self.game)


class PartyListShareTests(TestCase):
    def setUp(self):
        self.owner = _make_user()
        self.shared_with = _make_user(username='shared', email='shared@example.com')
        self.party_list = PartyList.objects.create(owner=self.owner, name='Shared List')

    def test_default_permission_is_view(self):
        share = PartyListShare.objects.create(
            party_list=self.party_list,
            shared_with_user=self.shared_with,
        )
        self.assertEqual(share.permission, PartyListShare.PERMISSION_VIEW)

    def test_default_accepted_is_false(self):
        share = PartyListShare.objects.create(
            party_list=self.party_list,
            shared_with_user=self.shared_with,
        )
        self.assertFalse(share.accepted)

    def test_unique_together_party_list_shared_with_user(self):
        PartyListShare.objects.create(
            party_list=self.party_list,
            shared_with_user=self.shared_with,
        )
        with self.assertRaises(IntegrityError):
            PartyListShare.objects.create(
                party_list=self.party_list,
                shared_with_user=self.shared_with,
            )


class GameRequestTests(TestCase):
    def setUp(self):
        self.owner = _make_user()
        self.requester = _make_user(username='requester', email='requester@example.com')
        self.game = _make_game()
        self.party_list = PartyList.objects.create(owner=self.owner, name='Borrow List')

    def test_default_status_is_pending(self):
        request = GameRequest.objects.create(
            party_list=self.party_list,
            requester=self.requester,
            owner=self.owner,
            game=self.game,
        )
        self.assertEqual(request.status, GameRequest.STATUS_PENDING)

    def test_message_blank_by_default(self):
        request = GameRequest.objects.create(
            party_list=self.party_list,
            requester=self.requester,
            owner=self.owner,
            game=self.game,
        )
        self.assertEqual(request.message, '')

    def test_status_constants_defined(self):
        self.assertEqual(GameRequest.STATUS_PENDING, 'pending')
        self.assertEqual(GameRequest.STATUS_ACCEPTED, 'accepted')
        self.assertEqual(GameRequest.STATUS_DECLINED, 'declined')


class LendingHistoryTests(TestCase):
    def setUp(self):
        self.user = _make_user()
        self.game = _make_game()

    def test_returned_date_optional(self):
        history = LendingHistory.objects.create(
            user=self.user,
            game=self.game,
            lent_to='Alice',
            lent_date='2026-05-09',
        )
        self.assertIsNone(history.returned_date)

    def test_notes_blank_by_default(self):
        history = LendingHistory.objects.create(
            user=self.user,
            game=self.game,
            lent_to='Alice',
            lent_date='2026-05-09',
        )
        self.assertEqual(history.lent_notes, '')
        self.assertEqual(history.return_notes, '')
