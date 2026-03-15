"""
Custom Django email backend that sends via Microsoft Graph API.

Uses the OAuth 2.0 client credentials flow (app-only auth).  An access token
is acquired once and reused until it expires; msal handles expiry and refresh
transparently via its in-memory token cache.

Azure prerequisites (one-time setup):
  1. Register an app in Entra ID (Azure Active Directory).
  2. Grant it the *application* permission: Mail.Send
     (NOT delegated — client credentials flow requires application permissions)
  3. Grant admin consent for that permission in the Entra portal.
  4. Create a client secret under the app registration.
  5. Set MS_GRAPH_TENANT_ID, MS_GRAPH_CLIENT_ID, MS_GRAPH_CLIENT_SECRET,
     and MS_GRAPH_SENDER in the production .env file.
"""

import logging
import threading

import msal
import requests
from django.core.mail.backends.base import BaseEmailBackend

logger = logging.getLogger(__name__)

_graph_app: "msal.ConfidentialClientApplication | None" = None
_graph_app_lock = threading.Lock()

_GRAPH_SCOPES = ["https://graph.microsoft.com/.default"]


def _get_app(tenant_id: str, client_id: str, client_secret: str) -> "msal.ConfidentialClientApplication":
    """Return (and lazily create) the module-level msal app singleton."""
    global _graph_app
    if _graph_app is None:
        with _graph_app_lock:
            if _graph_app is None:
                authority = f"https://login.microsoftonline.com/{tenant_id}"
                _graph_app = msal.ConfidentialClientApplication(
                    client_id=client_id,
                    client_credential=client_secret,
                    authority=authority,
                )
    return _graph_app


class GraphEmailBackend(BaseEmailBackend):
    """
    Django email backend that sends via Microsoft Graph API.

    Drop-in replacement for Django's SMTP backend.  Set EMAIL_BACKEND in
    settings.py to 'accounts.graph_email_backend.GraphEmailBackend'.

    Also reads:
        settings.MS_GRAPH_TENANT_ID
        settings.MS_GRAPH_CLIENT_ID
        settings.MS_GRAPH_CLIENT_SECRET
        settings.MS_GRAPH_SENDER   — the licensed mailbox to send from
    """

    def send_messages(self, email_messages):
        from django.conf import settings

        tenant_id = settings.MS_GRAPH_TENANT_ID
        client_id = settings.MS_GRAPH_CLIENT_ID
        client_secret = settings.MS_GRAPH_CLIENT_SECRET
        sender = settings.MS_GRAPH_SENDER

        app = _get_app(tenant_id, client_id, client_secret)

        # acquire_token_for_client returns a cached token when still valid
        result = app.acquire_token_for_client(scopes=_GRAPH_SCOPES)

        if "access_token" not in result:
            error = result.get("error_description") or result.get("error") or "unknown"
            logger.error("Graph token acquisition failed: %s", error)
            if not self.fail_silently:
                raise RuntimeError(f"Microsoft Graph token acquisition failed: {error}")
            return 0

        token = result["access_token"]
        endpoint = f"https://graph.microsoft.com/v1.0/users/{sender}/sendMail"
        headers = {"Authorization": f"Bearer {token}"}

        num_sent = 0
        for message in email_messages:
            to_recipients = [
                {"emailAddress": {"address": addr}}
                for addr in message.to
            ]
            payload = {
                "message": {
                    "subject": message.subject,
                    "body": {
                        "contentType": "Text",
                        "content": message.body,
                    },
                    "toRecipients": to_recipients,
                    "from": {"emailAddress": {"address": sender}},
                },
                "saveToSentItems": False,
            }

            try:
                response = requests.post(endpoint, json=payload, headers=headers, timeout=15)
                if response.status_code == 202:
                    num_sent += 1
                else:
                    logger.error(
                        "Graph sendMail failed: HTTP %s — %s",
                        response.status_code,
                        response.text,
                    )
                    if not self.fail_silently:
                        raise RuntimeError(
                            f"Graph sendMail failed: HTTP {response.status_code}: {response.text}"
                        )
            except requests.RequestException as exc:
                logger.exception("Graph sendMail request error: %s", exc)
                if not self.fail_silently:
                    raise

        return num_sent
