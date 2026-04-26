# Unit Test Gaps

Areas of the codebase that cannot have automated unit tests written today,
and what needs to change before they can be covered.

---

## 1. Django — `catalog.bgg.fetch_collection()`

**File:** `web/catalog/bgg.py`

**Why it can't be tested:**
`fetch_collection()` makes live HTTP requests to `boardgamegeek.com` with real
rate-limiting delays (`time.sleep(2.0)` before every attempt, `time.sleep(5.0)`
on 202 retry). Even with `unittest.mock.patch('requests.get', ...)` the sleep
calls still execute, making any test suite that mocks the HTTP layer take
10+ seconds per test case. More critically, the 202-retry logic and the
`time.sleep` interleave make the code hard to exercise exhaustively without
either (a) waiting real time or (b) also mocking `time.sleep`, which obscures
the intent.

**Untested scenarios:**
- 202 "still preparing" response triggers a retry after 5 s delay
- Exhausting `_MAX_RETRIES` retries raises `BGGError`
- `requests.RequestException` (network failure) raises `BGGError`
- 4xx/5xx responses raise `BGGError` with the HTTP status code
- Authorization header included only when `BGG_API_TOKEN` is set and not a placeholder

**What needs to change:**
Inject an `http_client` parameter (defaulting to `requests`) and extract
`time.sleep` into a `_sleep(seconds)` helper so tests can patch both without
real I/O. Example refactor:

```python
def fetch_collection(username: str, *, _http=requests, _sleep=time.sleep) -> list[BGGGame]:
    ...
    _sleep(_REQUEST_DELAY)
    response = _http.get(url, ...)
```

---

## 2. Django — `catalog.gameupc` (network paths, `_base_url`, `_api_key`)

**File:** `web/catalog/gameupc.py`

**Partially covered:** `lookup_barcode()` and `submit_barcode_mapping()` are
already tested via `unittest.mock.patch('catalog.gameupc.requests.get/post')`.
The remaining gap is integration testing against the real GameUPC test
environment (`https://api.gameupc.com/test/`) using the public test key.

**Untested scenarios:**
- Case 2 (REQ-GU-002): `bgg_info` contains multiple candidates — the code
  silently picks `bgg_info[0]` without checking `bgg_info_status`. The correct
  behaviour (prompt user to choose) is documented in
  `docs/features/gameupc-feature-requests.md` but not yet implemented, so there
  is nothing to test yet.
- Case 3 (REQ-GU-003): `bgg_info_status == 'unlinked'` — the in-app BGG search
  flow is not yet implemented.

**What needs to change:**
Implement Cases 2 and 3 per `gameupc-feature-requests.md`, then add unit tests
for the new branching logic using mocked responses.

---

## 3. Django — `accounts.graph_email_backend.GraphEmailBackend`

**File:** `web/accounts/graph_email_backend.py`

**Why it can't be tested:**
The Graph email backend authenticates against Azure Active Directory using MSAL
(`ConfidentialClientApplication.acquire_token_for_client`) and then calls the
Microsoft Graph API (`POST /v1.0/users/{sender}/sendMail`). These are live cloud
calls that require valid Azure credentials (`MS_TENANT_ID`, `MS_CLIENT_ID`,
`MS_CLIENT_SECRET`, `MS_SENDER_EMAIL`) — credentials that do not (and should
not) exist in a CI environment.

**Untested scenarios:**
- MSAL token acquisition success → Graph API called with correct payload
- MSAL token acquisition failure → `smtplib.SMTPException` raised
- Graph API 4xx/5xx → exception raised
- Email address and body encoding

**What needs to change:**
Inject the MSAL client as a constructor parameter (defaulting to the real
`ConfidentialClientApplication`) so tests can supply a mock. Example:

```python
class GraphEmailBackend(BaseEmailBackend):
    def __init__(self, *args, msal_client=None, **kwargs):
        super().__init__(*args, **kwargs)
        self._msal_client = msal_client  # injected in tests
```

Then mock the injected client and the `requests.post` Graph call.

---

## 4. Django — `accounts.email.send_verification_email()`

**File:** `web/accounts/email.py`

**Why it can't be tested:**
`send_verification_email()` calls Django's `send_mail()`, which in turn invokes
whichever email backend is configured. In production this is `GraphEmailBackend`
(see §3). Even if the test suite uses `django.core.mail.backends.locmem.EmailBackend`
(the in-memory test backend), the function builds a verification URL via
`request.build_absolute_uri()`, which requires a real `HttpRequest` object from
a request cycle.

**What can be tested now (partially):**
Switch to Django's in-memory backend with `@override_settings(EMAIL_BACKEND=...)`
and provide a `RequestFactory` request. This covers the URL construction and
message content. It is blocked only by the absence of a test fixture for this
function in the current test suite — add it to `accounts/tests/test_email.py`.

**Remaining gap (after the above):**
The Graph backend itself (§3) is still not covered.

---

## 5. Django — Web Views (`catalog.views`)

**File:** `web/catalog/views.py`

**Why not currently covered:**
The web views (`CollectionView`, `SyncBGGView`, `ManageListsView`,
`ListDetailView`, etc.) are rendered via Django templates and require
`login_required`. They can be tested today with Django's `TestClient` and
`client.force_login(user)`.

**Why tests were deferred:**
`SyncBGGView.post()` calls either `bgg.parse_collection_xml()` (from
browser-submitted XML) or `bgg.fetch_collection()` (server-side). The
server-side path has the network/sleep problem described in §1. The
browser-side path (`parse_collection_xml`) is pure and testable today.

**What needs to change (§1 fix unblocks this):**
Once `fetch_collection()` accepts dependency-injected HTTP and sleep, the
`SyncBGGView` test can mock those and fully cover:
- Successful BGG sync updates collection (non-destructive)
- UPC field never overwritten on existing games
- Empty BGG collection produces correct flash message
- BGG error response shows user-facing error

**CollectionView filtering and sorting** — fully testable today. Deferred
only due to time; add to `catalog/tests/test_views.py`.

---

## 6. Flutter — `ApiService` (HTTP calls)

**File:** `mobile/lib/services/api_service.dart`

**Why it can't be tested:**
`ApiService` calls `http.get(...)`, `http.post(...)`, etc. from the `http`
package directly (top-level functions), not through an injected `http.Client`.
There is no seam to substitute a mock HTTP client without modifying the
production code.

**Affected methods:** all of them — `validateKey`, `fetchCollection`,
`scanBarcode`, `linkBarcode`, `fetchLists`, `createList`, etc.

**What needs to change:**
Accept an `http.Client` in the constructor (defaulting to `http.Client()`):

```dart
class ApiService {
  final String apiKey;
  final http.Client _client;

  ApiService(this.apiKey, {http.Client? client})
      : _client = client ?? http.Client();
```

Then replace every `http.get(...)` call with `_client.get(...)`.
Tests can then inject `MockClient` from the `http` package's test helpers
(`package:http/testing.dart`) or use `mocktail`.

---

## 7. Flutter — `AuthService` (secure storage)

**File:** `mobile/lib/services/auth_service.dart`

**Why it can't be tested:**
`AuthService` calls `FlutterSecureStorage` directly (instantiated inside the
class). `FlutterSecureStorage` invokes platform channel methods (`MethodChannel`)
that are not available in the Dart-only test environment; running the test
throws `MissingPluginException`.

**What needs to change:**
Accept `FlutterSecureStorage` as a constructor parameter (defaulting to the
real implementation):

```dart
class AuthService {
  final FlutterSecureStorage _storage;
  AuthService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(...);
```

Then inject a mock (using `mocktail` or `mockito`) in tests.

---

## 8. Flutter — `CollectionProvider` (network + SharedPreferences cache)

**File:** `mobile/lib/providers/collection_provider.dart`

**Why it can't be tested:**
`CollectionProvider.load()` constructs `ApiService(apiKey)` inline — no
injection point for a mock HTTP client. `_saveCache()` and `_tryLoadCache()`
call `SharedPreferences.getInstance()`, which invokes platform channels
unavailable in the test environment.

**Untested scenarios:**
- `load()` on network success populates `_items` and transitions to `LoadState.loaded`
- `load()` on network error falls back to cache and shows error state
- `setQuery()` filters the returned items list
- Cache round-trip (save then load) restores items correctly
- `_state` transitions: `idle → loading → loaded/error`

**What needs to change:**
1. Inject `ApiService` (or a factory `Future<ApiService> Function()`) so the
   provider doesn't construct it internally.
2. Use `SharedPreferences.setMockInitialValues({})` in `setUp()` (available from
   the `shared_preferences` package's test helper) to enable in-process testing.

---

## 9. Flutter — `ListProvider` (network calls)

**File:** `mobile/lib/providers/list_provider.dart`

**Why it can't be tested:**
Same root cause as `CollectionProvider` (§8): `ListProvider` constructs
`ApiService(apiKey)` inline. All CRUD methods (`load`, `createList`,
`updateList`, `deleteList`, `fetchDetail`, `removeFromList`, `updateEntryNote`)
are untestable without an injection point.

**Untested scenarios:**
- `createList` appends the new list to `_lists` on success
- `deleteList` removes the list from `_lists` on success
- `updateList` replaces the matching list in `_lists` on success
- `load` error transitions to `LoadState.error` and sets `_error`
- Any method failure sets `_error` and calls `notifyListeners()`

**What needs to change:**
Same fix as `ApiService` (§6) + provider injection (§8). Once `ApiService`
accepts an `http.Client`, the provider tests can inject a mock client factory.

---

## 10. Flutter — `AuthProvider` (secure storage + network)

**File:** `mobile/lib/providers/auth_provider.dart`

**Why it can't be tested:**
`AuthProvider.initialize()` calls `AuthService().getApiKey()` (platform channel
— §7) and `ApiService(key).validateKey()` (HTTP — §6). `login()` calls
`AuthService().saveApiKey()`. Neither service is injected.

**Untested scenarios:**
- `initialize()` with stored key validates successfully → `AuthState.loggedIn`
- `initialize()` with stored key that fails validation → `AuthState.loggedOut`
- `initialize()` with no stored key → `AuthState.loggedOut`
- `login()` saves key and transitions to `AuthState.loggedIn`
- `logout()` clears key and transitions to `AuthState.loggedOut`

**What needs to change:**
Inject both `AuthService` and `ApiService` (or a factory) into `AuthProvider`.

---

## 11. Flutter — Widget / Screen Tests

**Files:** `mobile/lib/screens/*.dart`, `mobile/lib/widgets/*.dart`

**Why they can't be tested:**
- `ScannerScreen` uses `MobileScannerController`, which invokes the device camera
  via platform channels. The `mobile_scanner` plugin has no test mode or fake
  implementation.
- `ScanModeScreen` requires a fully functional `ListProvider` (§9).
- `ListDetailScreen` and `ListsScreen` require functional `ListProvider` (§9).
- `ScanResultCard` can be widget-tested today (it is a pure display widget with
  no platform dependencies), but it was not prioritised in this phase.

**What needs to change:**
1. Fix §6–10 (service and provider injection) to unblock screen tests.
2. For `ScannerScreen`, use `mobile_scanner`'s `MockMobileScannerController`
   when it becomes available upstream, or wrap the camera controller behind an
   interface that can be swapped for a fake.
3. Add `ScanResultCard` widget test immediately — no blockers exist.

---

## Summary Table

| Area | Blocker | Fix Required |
|---|---|---|
| `bgg.fetch_collection()` | Live HTTP + real `time.sleep` | Inject `_http`, `_sleep` params |
| `gameupc` Cases 2 & 3 | Feature not yet implemented | Implement REQ-GU-002/003 first |
| `GraphEmailBackend` | Live Azure AD calls | Inject MSAL client |
| `send_verification_email()` | Partial — only Graph backend | Fix §3 |
| Web views (`SyncBGGView`) | `fetch_collection` network (§1) | Fix §1 |
| Flutter `ApiService` | Direct `http.*` calls | Accept `http.Client` param |
| Flutter `AuthService` | `FlutterSecureStorage` platform channel | Accept storage param |
| Flutter `CollectionProvider` | Inline `ApiService` + `SharedPreferences` | Inject service + use test prefs |
| Flutter `ListProvider` | Inline `ApiService` | Inject service |
| Flutter `AuthProvider` | Inline service construction | Inject both services |
| Flutter screens | Providers blocked + camera hardware | Fix §6–10, wrap camera |
| Flutter `ScanResultCard` widget | **None** | Write test now |
