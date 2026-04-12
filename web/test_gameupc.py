"""
Manual test script for the GameUPC API integration.

Run from the web/ directory with the .env file present:
    cd web
    python test_gameupc.py

Tests all three confidence scenarios using Bob's test UPCs:
    111111111117  — verified (strong single result)
    222222222224  — choose_from_bgg_info_or_search (multiple candidates)
    333333333331  — new/unknown (no data)
"""

import os
import sys
from pathlib import Path

# Load .env from web/ directory
env_path = Path(__file__).parent / '.env'
if not env_path.exists():
    print(f"ERROR: No .env file found at {env_path}")
    sys.exit(1)

# Parse .env manually (avoids needing python-dotenv installed outside venv)
with open(env_path) as f:
    for line in f:
        line = line.strip()
        if line and not line.startswith('#') and '=' in line:
            key, _, value = line.partition('=')
            os.environ.setdefault(key.strip(), value.strip())

import django
sys.path.insert(0, str(Path(__file__).parent))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'boardgame_catalog.settings')
django.setup()

from catalog.gameupc import lookup_barcode, submit_barcode_mapping, GameNotFound, GameUPCError

TEST_UPCS = [
    ('111111111117', 'Verified — strong single result (Splendor)'),
    ('222222222224', 'Ambiguous — multiple candidates (Tiny Towns variants)'),
    ('333333333331', 'Unknown — no data in database'),
]


def separator(title):
    print(f"\n{'=' * 60}")
    print(f"  {title}")
    print('=' * 60)


def test_lookup(upc, description):
    separator(f"UPC {upc} — {description}")
    try:
        result = lookup_barcode(upc)
        print(f"  ✓ Found: {result.title}")
        print(f"    BGG ID:       {result.bgg_id}")
        print(f"    Year:         {result.year_published}")
        print(f"    Players:      {result.min_players}–{result.max_players}")
        print(f"    Playing time: {result.playing_time} min")
        print(f"    Thumbnail:    {result.thumbnail_url[:60]}...")
    except GameNotFound as e:
        print(f"  ✗ Not found: {e}")
    except GameUPCError as e:
        print(f"  ✗ API error: {e}")


def test_submit(upc, bgg_id):
    separator(f"Submit mapping UPC {upc} → BGG {bgg_id}")
    success = submit_barcode_mapping(upc, bgg_id, user_id=0)
    if success:
        print(f"  ✓ Mapping submitted successfully")
    else:
        print(f"  ✗ Submission failed (check logs)")


if __name__ == '__main__':
    from django.conf import settings
    api_key = getattr(settings, 'GAMEUPC_API_KEY', '')
    is_test = not api_key or api_key.startswith('CHANGE-ME')
    env_label = 'TEST (test_test_test_test_test)' if is_test else 'PRODUCTION'
    print(f"\nGameUPC environment: {env_label}")

    # Test all three lookup scenarios
    for upc, description in TEST_UPCS:
        test_lookup(upc, description)

    # Test submit-back using the verified UPC + its known BGG ID (Splendor = 148228)
    print()
    test_submit('111111111117', 148228)

    print(f"\n{'=' * 60}")
    print("  Done.")
    print('=' * 60)
