"""
Microsoft Graph email diagnostic script.

Run inside the Docker container where .env and dependencies are available.

Usage:
    # Step 1 — test token acquisition only (no email sent):
    docker exec boardgame_catalog python test_graph_email.py

    # Step 2 — also send a test email:
    docker exec boardgame_catalog python test_graph_email.py --send-to you@example.com
"""

import os
import sys

from dotenv import load_dotenv

load_dotenv()

TENANT_ID     = os.environ.get('MS_GRAPH_TENANT_ID', '')
CLIENT_ID     = os.environ.get('MS_GRAPH_CLIENT_ID', '')
CLIENT_SECRET = os.environ.get('MS_GRAPH_CLIENT_SECRET', '')
SENDER        = os.environ.get('MS_GRAPH_SENDER', '')

# ── Validate env vars are present ─────────────────────────────────────────────

print("\n── Step 1: Environment variables ───────────────────────────────")
missing = []
for name, val in [
    ('MS_GRAPH_TENANT_ID',     TENANT_ID),
    ('MS_GRAPH_CLIENT_ID',     CLIENT_ID),
    ('MS_GRAPH_CLIENT_SECRET', CLIENT_SECRET),
    ('MS_GRAPH_SENDER',        SENDER),
]:
    if val and not val.startswith('CHANGE-ME'):
        print(f"  ✓  {name}")
    else:
        print(f"  ✗  {name}  ← not set or still placeholder")
        missing.append(name)

if missing:
    print(f"\nAborting: {len(missing)} variable(s) not configured in .env\n")
    sys.exit(1)

# ── Acquire token ─────────────────────────────────────────────────────────────

print("\n── Step 2: Token acquisition ───────────────────────────────────")
try:
    import msal
except ImportError:
    print("  ✗  msal not installed (run: pip install msal)")
    sys.exit(1)

authority = f"https://login.microsoftonline.com/{TENANT_ID}"
app = msal.ConfidentialClientApplication(
    client_id=CLIENT_ID,
    client_credential=CLIENT_SECRET,
    authority=authority,
)

result = app.acquire_token_for_client(scopes=["https://graph.microsoft.com/.default"])

if "access_token" in result:
    token = result["access_token"]
    print(f"  ✓  Token acquired  (expires in {result.get('expires_in', '?')}s)")
else:
    error = result.get("error_description") or result.get("error") or "unknown"
    print(f"  ✗  Token acquisition failed: {error}")
    print("\n  Common causes:")
    print("    - Wrong TENANT_ID or CLIENT_ID")
    print("    - Client secret expired or copied incorrectly")
    print("    - Mail.Send permission not granted or admin consent not given")
    sys.exit(1)

# ── Optional: send test email ─────────────────────────────────────────────────

send_to = None
for arg in sys.argv[1:]:
    if arg.startswith('--send-to='):
        send_to = arg.split('=', 1)[1]
    elif arg == '--send-to' and sys.argv.index(arg) + 1 < len(sys.argv):
        send_to = sys.argv[sys.argv.index(arg) + 1]

if send_to is None:
    print("\n── Step 3: Send test email ─────────────────────────────────────")
    print("  (skipped — pass --send-to=you@example.com to test sending)\n")
    print("Token acquisition succeeded. Graph credentials look correct.\n")
    sys.exit(0)

print(f"\n── Step 3: Sending test email to {send_to} ─────────────────────")
try:
    import requests as req
except ImportError:
    print("  ✗  requests not installed (run: pip install requests)")
    sys.exit(1)

endpoint = f"https://graph.microsoft.com/v1.0/users/{SENDER}/sendMail"
payload = {
    "message": {
        "subject": "Board Game Catalog — Graph email test",
        "body": {
            "contentType": "Text",
            "content": (
                "This is a test email sent by test_graph_email.py.\n\n"
                "If you received this, Microsoft Graph email is working correctly.\n\n"
                f"Sent from: {SENDER}\n"
            ),
        },
        "toRecipients": [{"emailAddress": {"address": send_to}}],
        "from": {"emailAddress": {"address": SENDER}},
    },
    "saveToSentItems": False,
}

response = req.post(
    endpoint,
    json=payload,
    headers={"Authorization": f"Bearer {token}"},
    timeout=15,
)

if response.status_code == 202:
    print(f"  ✓  Email accepted by Graph API (202). Check {send_to}\n")
else:
    print(f"  ✗  Graph API returned HTTP {response.status_code}")
    print(f"     {response.text}\n")
    print("  Common causes:")
    print("    - MS_GRAPH_SENDER mailbox does not exist or is not licensed")
    print("    - Mail.Send permission is delegated instead of application type")
    print("    - Admin consent was not granted\n")
    sys.exit(1)
