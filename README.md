# DriverFrontend

Flutter frontend for the logistics / driver platform.

The app lives in **[`logistics_app/`](logistics_app/)**. That folder has the full README: features, roles, screens, models, API calls, auth, WebSocket GPS, setup, and known gaps.

```bash
cd logistics_app
flutter pub get
flutter run
```

The backend is expected at `http://192.168.32.85:8080` (hardcoded). Change that IP in `logistics_app/lib` if your server is elsewhere.
