# BoardMasters Review Center Mobile App

Flutter app for the BoardMasters Review Center project.

## Included Flow

- Splash screen with branded logo animation
- Onboarding
- Registration and login
- Home dashboard with Free and Subscription plan cards
- Plan-based feature visibility
- Subject selection and question count picker
- Quiz flow with A/B/C/D rationalization
- Result screen with animated score
- Profile with recent attempts

## One-Time Setup

```bash
cd app-review-center
flutter pub get
copy .env.example .env
```

Edit `.env` (gitignored) and set `API_BASE_URL`:

- Dev (Docker): `http://api.boardmasters.local:8080/api`
- Prod: `https://api.boardmasters.com/api`

Optional for Terms/Privacy links inside the app:

- Dev: `WEBSITE_BASE_URL=http://boardmasters.local:8080`
- Prod: `WEBSITE_BASE_URL=https://boardmasters.com`

## Run Backend + Web + Flutter Together

1. Start Laravel API/backend (shared by web and mobile):

```bash
cd ..\BOARDMASTER-REVIEW-CENTER
php artisan serve --host=0.0.0.0 --port=8000
```

2. Start Laravel web UI (Vite):

```bash
cd ..\BOARDMASTER-REVIEW-CENTER
npm run dev
```

3. Start Flutter mobile app:

```bash
cd ..\app-review-center
flutter run
```

4. Start Flutter web app (optional):

```bash
cd ..\app-review-center
flutter run -d chrome
```

Optional override at run time:

```bash
flutter run --dart-define=API_BASE_URL=http://api.boardmasters.local:8080/api
```

## Google Sign-In Setup (Flutter Mobile)

1. In Firebase Console, open your project and go to `Authentication > Sign-in method`.
2. Enable `Google` provider.
3. Go to `Project settings > Your apps > Android app`.
4. Confirm package name is `ph.boardmaster.app_review_center`.
5. Add SHA-1 and SHA-256 fingerprints for your debug/release keystores.
6. In `Project settings > General`, find the OAuth section and copy the **Web client ID**.
7. Set `GOOGLE_SERVER_CLIENT_ID=<your web client id>` in Flutter `.env`.
8. In backend `.env`, set `GOOGLE_AUTH_AUDIENCES` with accepted client IDs (at minimum your Web client ID).
9. Run:

```bash
flutter pub get
flutter run
```

## Login Troubleshooting (Mobile)

- Ensure your device can resolve `api.boardmasters.local` (DNS/hosts entry) in dev.
- Open `http://api.boardmasters.local:8080/api/mobile/plans`; it should return JSON.
- API routes are host-restricted, so `boardmasters.local` and `app.boardmasters.local` cannot serve `/api/*`.

## Build APK

```bash
cd app-review-center
flutter build apk --release
```

APK output:

- `app-review-center/build/app/outputs/flutter-apk/app-release.apk`

