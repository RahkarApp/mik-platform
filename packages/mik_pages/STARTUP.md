# Shared app startup

MiK and MiKYar use the same startup structure:

1. `StartupFX.prepare` initializes Flutter, orientation and system bars, then runs
   any host platform setup (MiKYar Firebase, Windows and web URL strategy).
2. `mik_components/base/startup/start_app.dart` owns `GetMaterialApp`, themes,
   locale, RTL, text scaling, notifications and system brightness observation.
3. `StartupScreen` owns the splash lifecycle and creates one `StartupController`.
4. The controller runs `prepare`, `readDatabase`, `readSettings` and `openApp`
   in order. A failure stops the sequence and offers retry. Disposal prevents
   subsequent steps and navigation; rebuilds do not restart initialization.

Each host supplies its router, connection startup and saved theme preference.
Its splash controller supplies the actual database, settings and account work.
MiKYar retains its encrypted Hive database. MiK retains its canonical shared
Hive database. Both hosts restore their own secure v1 authentication session
and open the shared login screen; MiK shows onboarding first for a new install.
The former v2 status and account bootstrap do not run against a v1 session.
MiK then loads its v1 business list or resumes owner onboarding. Successful
registration opens welcome, whose continue button opens the host dashboard.
The host prepares local presentation in caches separated by API origin,
identity and business. Financial/product endpoints and realtime transport
still need their separate migrations.

Theme and layout state come from `mik_variables` in both apps. Database update
progress remains host-specific and is passed to the shared splash. The splash
uses the existing `BTN`, `MyLinearProgress` and packaged logo. Each widget has
its own file.

Host `main.dart` files only prepare the runtime and launch their `StartApp`.
`App` / `MyApp` and existing splash paths remain compatible entry points for
routes that restart initialization.
