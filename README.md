# RakshaPay Mobile (Flutter)

Same dark/cyan design as the web app. Talks to the same FastAPI backend,
which stores everything in Supabase Postgres -> web and mobile stay in sync.

## Setup
1. `flutter create rakshapay_mobile --org com.rakshapay`
2. Copy `lib/` and `pubspec.yaml` from this folder over the generated ones.
3. `flutter pub get`
4. Android: make sure `android/app/src/main/AndroidManifest.xml` has
   `<uses-permission android:name="android.permission.INTERNET"/>` (needed for release builds),
   and `minSdkVersion` is 23 or higher in `android/app/build.gradle`.
5. Run:
   - Against deployed backend: `flutter run`
   - Against local backend (Android emulator): `flutter run --dart-define=API_BASE=http://10.0.2.2:8000`
   - Real phone + local backend: use your PC's LAN IP, e.g. `--dart-define=API_BASE=http://192.168.1.5:8000`
     (plain http needs `android:usesCleartextTraffic="true"` on <application> for debug only)

Apply the backend changes first (see chat reply), otherwise /api/transfer and /api/user/me won't accept the JWT.

## Structure
lib/main.dart            app entry, picks Login or Home based on saved token
lib/theme.dart           colour palette (same as CSS vars), fonts, shared widgets
lib/api.dart             all HTTP calls + token/device-id storage
lib/screens/             login (+risk decision + OTP sheets), register, dashboard, transfer
