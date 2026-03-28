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

- Physical phone on same Wi-Fi: `http://<YOUR_PC_IPV4>:8000/api`
- Android emulator: `http://10.0.2.2:8000/api`
- Flutter web on same machine: `http://127.0.0.1:8000/api`

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
flutter run --dart-define-from-file=.env
```

4. Start Flutter web app (optional):

```bash
cd ..\app-review-center
flutter run -d chrome --dart-define-from-file=.env
```

## Login Troubleshooting (Mobile)

- Make sure phone and computer are on the same Wi-Fi.
- Use your computer IPv4 in `.env` for physical device (not `127.0.0.1`).
- Keep Laravel running with `--host=0.0.0.0`.
- Open `http://<YOUR_PC_IPV4>:8000/api/mobile/plans` on phone browser. It should return JSON.
- If unreachable, allow `php` through Windows Firewall or open port `8000`.

## Build APK

```bash
cd app-review-center
flutter build apk --release --dart-define-from-file=.env
```

APK output:

- `app-review-center/build/app/outputs/flutter-apk/app-release.apk`

