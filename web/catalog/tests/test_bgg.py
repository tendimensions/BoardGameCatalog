"""
Unit tests for catalog.bgg module.

fetch_collection() makes live HTTP calls and is tested separately via
integration tests (see docs/testing/unit-test-gaps.md).  The pure
functions parse_collection_xml(), _fix_url(), and _int_or_none() are
fully testable without network access.
"""
from django.test import TestCase

from catalog.bgg import BGGError, BGGGame, _fix_url, _int_or_none, parse_collection_xml


def _collection_xml(items='', total='1'):
    """Wrap item XML fragments in a valid BGG collection envelope."""
    return f'<?xml version="1.0" encoding="utf-8"?><items totalitems="{total}">{items}</items>'


def _owned_item(objectid=174430, name='Gloomhaven', year='2017',
                min_players='1', max_players='4', playing_time='120',
                thumbnail='//cf.geekdo-images.com/thumb.jpg',
                image='//cf.geekdo-images.com/image.jpg',
                own='1'):
    return f"""
    <item objectid="{objectid}" subtype="boardgame">
      <name sortindex="1">{name}</name>
      <yearpublished>{year}</yearpublished>
      <thumbnail>{thumbnail}</thumbnail>
      <image>{image}</image>
      <stats minplayers="{min_players}" maxplayers="{max_players}"
             minplaytime="60" maxplaytime="120" playingtime="{playing_time}" numowned="50000">
      </stats>
      <status own="{own}" prevowned="0" fortrade="0" want="0" wanttoplay="0"
              wanttoown="0" wishlist="0" preordered="0" lastmodified="2024-01-01 00:00:00"/>
    </item>"""


# ── _int_or_none ──────────────────────────────────────────────────────────────

class IntOrNoneTests(TestCase):
    def test_positive_int_string(self):
        self.assertEqual(_int_or_none('5'), 5)

    def test_positive_int(self):
        self.assertEqual(_int_or_none(10), 10)

    def test_zero_returns_none(self):
        self.assertIsNone(_int_or_none(0))

    def test_zero_string_returns_none(self):
        self.assertIsNone(_int_or_none('0'))

    def test_negative_returns_none(self):
        self.assertIsNone(_int_or_none(-1))

    def test_none_returns_none(self):
        self.assertIsNone(_int_or_none(None))

    def test_non_numeric_string_returns_none(self):
        self.assertIsNone(_int_or_none('abc'))

    def test_float_string_returns_none(self):
        """'3.5' cannot be parsed as int."""
        self.assertIsNone(_int_or_none('3.5'))

    def test_empty_string_returns_none(self):
        self.assertIsNone(_int_or_none(''))


# ── _fix_url ──────────────────────────────────────────────────────────────────

class FixUrlTests(TestCase):
    def test_protocol_relative_gets_https(self):
        self.assertEqual(
            _fix_url('//cf.geekdo-images.com/image.jpg'),
            'https://cf.geekdo-images.com/image.jpg',
        )

    def test_already_https_unchanged(self):
        self.assertEqual(
            _fix_url('https://example.com/image.jpg'),
            'https://example.com/image.jpg',
        )

    def test_http_unchanged(self):
        self.assertEqual(
            _fix_url('http://example.com/image.jpg'),
            'http://example.com/image.jpg',
        )

    def test_empty_string_returns_empty(self):
        self.assertEqual(_fix_url(''), '')

    def test_none_returns_empty(self):
        self.assertEqual(_fix_url(None), '')

    def test_strips_whitespace(self):
        self.assertEqual(
            _fix_url('  //example.com/img.jpg  '),
            'https://example.com/img.jpg',
        )


# ── parse_collection_xml ──────────────────────────────────────────────────────

class ParseCollectionXmlTests(TestCase):
    def test_parses_single_owned_item(self):
        xml = _collection_xml(items=_owned_item())
        games = parse_collection_xml(xml)
        self.assertEqual(len(games), 1)

    def test_game_fields_extracted(self):
        xml = _collection_xml(items=_owned_item(
            objectid=174430, name='Gloomhaven', year='2017',
            min_players='1', max_players='4', playing_time='120',
        ))
        game = parse_collection_xml(xml)[0]
        self.assertIsInstance(game, BGGGame)
        self.assertEqual(game.bgg_id, 174430)
        self.assertEqual(game.title, 'Gloomhaven')
        self.assertEqual(game.year_published, 2017)
        self.assertEqual(game.min_players, 1)
        self.assertEqual(game.max_players, 4)
        self.assertEqual(game.playing_time, 120)

    def test_thumbnail_url_converted_to_https(self):
        xml = _collection_xml(items=_owned_item(
            thumbnail='//cf.geekdo-images.com/thumb.jpg'
        ))
        game = parse_collection_xml(xml)[0]
        self.assertTrue(game.thumbnail_url.startswith('https://'))

    def test_image_url_converted_to_https(self):
        xml = _collection_xml(items=_owned_item(
            image='//cf.geekdo-images.com/image.jpg'
        ))
        game = parse_collection_xml(xml)[0]
        self.assertTrue(game.image_url.startswith('https://'))

    def test_non_owned_items_excluded(self):
        xml = _collection_xml(items=_owned_item(own='0'))
        games = parse_collection_xml(xml)
        self.assertEqual(len(games), 0)

    def test_mixed_owned_and_not_owned(self):
        items = _owned_item(objectid=1, name='Owned') + _owned_item(objectid=2, name='Not Owned', own='0')
        xml = _collection_xml(items=items)
        games = parse_collection_xml(xml)
        self.assertEqual(len(games), 1)
        self.assertEqual(games[0].title, 'Owned')

    def test_empty_collection_returns_empty_list(self):
        xml = _collection_xml(items='', total='0')
        games = parse_collection_xml(xml)
        self.assertEqual(games, [])

    def test_multiple_owned_items(self):
        items = (
            _owned_item(objectid=1, name='Game One') +
            _owned_item(objectid=2, name='Game Two') +
            _owned_item(objectid=3, name='Game Three')
        )
        xml = _collection_xml(items=items)
        games = parse_collection_xml(xml)
        self.assertEqual(len(games), 3)

    def test_missing_year_returns_none(self):
        item = f"""
        <item objectid="999" subtype="boardgame">
          <name sortindex="1">No Year Game</name>
          <stats minplayers="2" maxplayers="4" playingtime="60" numowned="100"></stats>
          <status own="1" prevowned="0" fortrade="0" want="0" wanttoplay="0"
                  wanttoown="0" wishlist="0" preordered="0" lastmodified="2024-01-01"/>
        </item>"""
        xml = _collection_xml(items=item)
        game = parse_collection_xml(xml)[0]
        self.assertIsNone(game.year_published)

    def test_zero_playing_time_returns_none(self):
        xml = _collection_xml(items=_owned_item(playing_time='0'))
        game = parse_collection_xml(xml)[0]
        self.assertIsNone(game.playing_time)

    def test_zero_min_players_returns_none(self):
        xml = _collection_xml(items=_owned_item(min_players='0'))
        game = parse_collection_xml(xml)[0]
        self.assertIsNone(game.min_players)

    def test_invalid_xml_raises_bgg_error(self):
        with self.assertRaises(BGGError):
            parse_collection_xml('this is not xml')

    def test_bgg_error_response_raises(self):
        xml = '<errors><error><message>Invalid username</message></error></errors>'
        with self.assertRaises(BGGError) as ctx:
            parse_collection_xml(xml)
        self.assertIn('Invalid username', str(ctx.exception))

    def test_item_missing_status_excluded(self):
        """Items without a <status> element should be skipped."""
        item = """
        <item objectid="101" subtype="boardgame">
          <name sortindex="1">Statusless Game</name>
          <stats minplayers="2" maxplayers="4" playingtime="60" numowned="10"></stats>
        </item>"""
        xml = _collection_xml(items=item)
        games = parse_collection_xml(xml)
        self.assertEqual(len(games), 0)

    def test_item_missing_stats_gives_none_values(self):
        item = f"""
        <item objectid="202" subtype="boardgame">
          <name sortindex="1">No Stats Game</name>
          <status own="1" prevowned="0" fortrade="0" want="0" wanttoplay="0"
                  wanttoown="0" wishlist="0" preordered="0" lastmodified="2024-01-01"/>
        </item>"""
        xml = _collection_xml(items=item)
        game = parse_collection_xml(xml)[0]
        self.assertIsNone(game.min_players)
        self.assertIsNone(game.max_players)
        self.assertIsNone(game.playing_time)
