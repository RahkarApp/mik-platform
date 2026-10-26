# Shared authentication

Both apps use `login/screen/screen.dart`, the existing `BTN`, `Input`, alerts
and bottom sheet, and `mik_data/utils/fx/auth.dart` for their session.

- MiK requests `/v1/auth/otp`. Only `USER_NOT_FOUND` offers registration;
  confirmation requests `/v1/auth/registration/otp`.
- MiKYar uses login only and displays a missing-account message for
  `USER_NOT_FOUND`. Its data layer also rejects registration.
- Verification sends the actual five-digit string to the endpoint matching
  the OTP purpose. Persian and Arabic digits are normalized to ASCII.
- A complete access/refresh pair is saved together in secure storage, with
  separate keys for each app and API origin. Restore refreshes expired access
  tokens, coalesces concurrent refreshes and persists the rotated pair.
- Logout revokes the server session and clears local credentials. Invalid
  refresh credentials are cleared; transient failures retain the saved session.

Set the gateway origin with `--dart-define=API_ORIGIN=http://host:port` for
local development. The default is `http://192.168.3.48:4000`. Requests include
the app ID, version and platform. Non-idempotent OTP operations are not retried
automatically.

All v1 authentication calls use `API.request(method, path, ...)`. It builds
the gateway URL, common headers and JSON body, enforces a timeout and reads
the structured response/error. Optional `branchId` and `idempotencyKey` add
their respective headers; the caller retains the key for the same user intent.
For authenticated APIs, use `AuthFX.forApp(appId).request(...)` to obtain a
current access token before sending. An expired access token is refreshed
through the same request function. Requests are not replayed on a 401.
Existing v2 endpoints retain their old contracts until their migration.

```dart
final businesses = await AuthFX.forApp('mik').request('GET', '/v1/businesses');
```

After verification or secure session restoration, MiK checks
`GET /v1/businesses`. An empty list opens the existing registration form,
adapted to `POST /v1/businesses/onboarding`. One business is selected directly;
multiple businesses show a selection list. MiKYar's host continues to the shared
products flow, with its own business picker and server permissions; it never
runs owner onboarding. Hosts can provide
`onAuthenticated` to replace the default continuation.

Remote models live in `mik_data/source/remote/models`, including `AuthSession`,
catalog categories/units, onboarding input and each object in the onboarding
response. Hive models remain separate. `BusinessFX` uses the common request
function, pages the business list, and loads catalog roots and children with
their real string codes. Names, activities and acquisition are required;
empty optional last name and referral are omitted.

The same owner form and two-step activity sheet use the packaged components.
Its old v2 registration, local profile assumptions and fabricated owner record
have been removed. The current onboarding contract does not accept a logo.
Successful onboarding shows the existing welcome screen. Its continue button
opens the actual host dashboard with a typed `BusinessSession`. Before rendering,
the host prepares the display profile and local preferences from the confirmed
business. Hive cache names include the API origin, identity and business ID;
existing data is retained separately. No legacy JWT, owner/person record or
accounting transaction is fabricated. Existing businesses returned by the
authenticated business list open the dashboard directly, including on a device
without a local cache. Multiple businesses show the selection screen first.
Their real ID, name and membership come from the server; local preferences are
initialized as needed. The welcome screen is shown after onboarding only.

MiK's route guard recognizes its current v1 session while its refresh token is
valid, including when the access token needs renewal. It does not require a
legacy Hive JWT for welcome, dashboard or subsequent private routes. Automatic
selection of a single business navigates once and does not show the picker.

Dashboard navigation and local presentation are ready; the remaining financial,
product and realtime endpoints still need their separate v1 migrations. The
dashboard does not invoke the old database migration or v2 login bootstrap to
open a newly registered business. Logout revokes the v1 session and retains the
isolated caches.

Before posting, the app saves the exact typed input and UUID idempotency key
in secure storage scoped by API origin and identity. A transient error or
malformed success retains them across restarts. The form resumes that intent
before checking businesses, since server-side initialization might be pending
even when the business already exists. Its fields remain fixed during a retry;
the retry sends the same body and key. Input/referral validation failures allow
correction. A complete, internally consistent response clears the pending
intent and makes its typed result available as `BusinessFX.current`.

The backend is unchanged. In the inspected server, `USER_NOT_FOUND`,
`USER_NOT_ACTIVE` and `OTP_WAIT` reference an undefined `error` in their
options; those branches can return an internal error instead. The app never
interprets an internal error as permission to register. The running service
must return the intended code for the corresponding UI branch to activate.

Validation uses mocked HTTP responses and widget tests; it does not send SMS
or exercise a deployed service.
