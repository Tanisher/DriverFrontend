# Logistics App (Driver Frontend)

Flutter client for a logistics fleet: drivers log trips, admins manage customers, loads, drivers, and vehicles. The app talks to a REST backend over HTTP and receives live vehicle GPS over a WebSocket.

**Version:** `1.0.0+1`  
**Package:** `logistics_app` (`com.example.logistics_app`)  
**Dart SDK:** `>=2.18.0 <3.0.0`

---

## Contents

- [What this app does](#what-this-app-does)
- [Prerequisites](#prerequisites)
- [Quick start](#quick-start)
- [Backend URL](#backend-url)
- [Roles and navigation](#roles-and-navigation)
- [Screens](#screens)
- [Project structure](#project-structure)
- [Data models](#data-models)
- [API reference (client)](#api-reference-client)
- [Authentication](#authentication)
- [Realtime vehicle location](#realtime-vehicle-location)
- [Dependencies](#dependencies)
- [Platform notes](#platform-notes)
- [Known gaps](#known-gaps)

---

## What this app does

Two user experiences share the same binary:

| Role | After login | What they can do |
|------|-------------|------------------|
| **DRIVER** | Driver trip sheet (`/driver`) | Pick an assigned load, run a two-leg trip (deadhead → loaded), record mileage / diesel / trailers, and enter a weighbridge reading for **BULK** cargo |
| **ADMIN** | Admin dashboard (`/admin`) | CRUD customers, loads, drivers, vehicles; assign drivers to vehicles; view vehicle faults; live GPS on vehicles |

Signup also offers **OFFICE** and **MECHANIC**, but login only routes **ADMIN** and **DRIVER**. Other roles show an “Unauthorized role” snackbar.

**Trailers** and **Orders** appear in the admin sidebar but are placeholders (no API, no data).

---

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable; Dart 2.18+)
- A running backend at the host/port below (default `http://192.168.32.85:8080`)
- For Android: Android Studio / SDK; for Windows: Visual Studio with C++ desktop workload; for web: Chrome

Check the toolchain:

```bash
flutter doctor
```

---

## Quick start

All commands run from this folder (`logistics_app/`):

```bash
flutter pub get
flutter run
```

Pick a device when prompted, or target one:

```bash
flutter devices
flutter run -d windows
flutter run -d chrome
flutter run -d <android-device-id>
```

Other useful commands:

```bash
flutter analyze
flutter test
flutter build apk
flutter build windows
flutter build web
```

---

## Backend URL

The API host is **hardcoded** in many files as:

```
http://192.168.32.85:8080
```

WebSocket:

```
ws://192.168.32.85:8080/ws
```

If the backend is on another machine or port, replace that IP everywhere it appears (login, signup, admin pages, driver trips, vehicle Dio base URL, WebSocket). There is no `.env` or shared config file yet.

Typical search:

```bash
rg "192.168.32.85" lib
```

Cleartext HTTP is used (not HTTPS). Android debug/profile manifests include `INTERNET`; the main `AndroidManifest.xml` does not declare it, and there is no `usesCleartextTraffic` flag. If Android release builds cannot reach the API, add those.

---

## Roles and navigation

Entry: `lib/main.dart` → `MaterialApp` with named routes.

| Route | Widget | Who uses it |
|-------|--------|-------------|
| `/landing` | `LandingScreen` | Initial route; Sign Up / Log In |
| `/signup` | `SignUpScreen` | Create account (role dropdown) |
| `/login` | `LoginScreen` | Username + password; JWT stored locally |
| `/driver` | `DriverTripSheet` | Drivers |
| `/admin` | `AdminDashboard` | Admins |

`/home` (`DriverListScreen`) is imported and commented out; it is not registered.

Login (`POST /api/auth/login`) expects JSON `{ "token", "role" }`. Token is saved via `AuthService`; then:

- `role == 'ADMIN'` → `/admin`
- `role == 'DRIVER'` → `/driver`
- anything else → snackbar, stay on login

---

## Screens

### Landing

Welcome copy and two full-width buttons: Sign Up, Log In.

### Sign up

Fields: username, email, password, role (`OFFICE`, `DRIVER`, `MECHANIC`, `ADMIN`). Role is required. Success navigates to `/login`.

### Login

Username + password. On `200`, saves JWT and routes by role.

### Driver trip sheet (`lib/screens/driver.dart`)

The driver screen is a **two-leg trip sheet**, not a one-shot create form. On open (and pull-to-refresh) it loads JWT user id (`id` / `userId` / `sub` / `user_id`), then:

1. `GET /api/drivers/me/assigned-loads` — pick a real assigned load (no hardcoded `loadId` / `customerId`).
2. `GET /api/drivers/me/assigned-vehicle` — read-only plate/make/model from the driver profile (no vehicle picker).
3. `GET /api/drivers/me/active-trip` — restore deadhead, loaded, or none so a killed app can resume.

Flow:

| Phase | What the driver does | API |
|-------|----------------------|-----|
| **Ready** | Select a load, enter start mileage, **Start trip** | `POST /api/driver-trips/deadhead-start` `{ loadId, startMileage, driverId }` |
| **Deadhead** | Banner “Deadhead — en route to pickup”. End mileage, then **Arrived / End deadhead** | `POST /api/driver-trips/deadhead-end` `{ tripId, endMileage }` |
| **Loaded** | Banner “Loaded — en route to delivery”. End mileage, diesel, trailer 1 and 2, then **Complete delivery** | `POST /api/driver-trips/loaded-trip-end` `{ tripId, endMileage, fuelLitres, trailer1, trailer2 }` |

If deadhead-end does not return a usable loaded-trip id, the sheet asks the driver to pull to refresh. It does **not** reuse the deadhead id or force status `LOADED`.

Mileage `400` / `422` rejections from the backend are shown on the end-mileage field, not as a generic toast.

**BULK vs BAGGED**

`Load.cargoType` comes from the assigned-load payload (`cargoType` / `cargo_type` / `loadType`).

- **BULK:** a **Weighbridge reading** field is shown at pickup (optional — the bridge may be at the other stop) and at delivery (required if still blank). Submitting that step first `PATCH /api/loads/{id}/actual-weight` with `{ "actualWeight": <number> }`, then the trip POST. After a successful save the field is hidden.
- **BAGGED:** the field is hidden; booked weight on the load record is enough.

There is no trip-history table and no destination field. Office admin **Loads** is still create/list/delete only — it does not collect `cargoType` or weighbridge readings.

### Admin dashboard (`lib/screens/admin/admin.dart`)

`NavigationRail` + content pane:

| Section | File | Status |
|---------|------|--------|
| Customers | `admin/customers.dart` | Implemented |
| Loads | `admin/load.dart` | Implemented |
| Drivers | `admin/driver.dart` | Implemented |
| Vehicles | `admin/vehicle.dart` | Implemented (+ WebSocket GPS) |
| Trailers | inline `TrailersPage` | Placeholder |
| Orders | inline `OrdersPage` | Placeholder |

### Customers

List name/email. Eye icon → `GET /api/customers/{id}` details dialog. FAB → add (name, email, contact, address). Delete currently uses **GET** on `/{id}` and then removes the row locally (not a real DELETE). `_validateCustomer` exists but is not called from the add flow.

### Loads

List by customer name (customers fetched first). FAB → dialog: customer dropdown, description, weight, pickup, delivery, status. Delete via `DELETE /api/loads/{id}`. The dialog does not set `cargoType`; drivers get BULK vs BAGGED from the assigned-load API.

### Drivers

List name / last name. FAB → dialog: name, last name, username, password, email, address, license, next of kin + contact, mobile, ID number. Delete via `DELETE /api/drivers/{id}` (`204`).

### Vehicles (`Dio` + WebSocket)

Cards: make, model, plate, year, color, active, last service. Actions: edit, delete, assign driver, faults (if present). FAB → add vehicle.

Live location: connect to `ws://…/ws` with `Authorization: Bearer <token>`. Messages `{ vehicleId, latitude, longitude }` update the matching vehicle in memory (not shown on a map UI yet).

---

## Project structure

Canonical source is **`lib/`**. Platform folders (`android/`, `ios/`, `windows/`, `web/`, `macos/`, `linux/`) are Flutter runners.

```
logistics_app/
├── lib/
│   ├── main.dart                 # Routes
│   ├── classes/                  # JSON models
│   │   ├── Customer.dart
│   │   ├── Driver.dart
│   │   ├── Load.dart
│   │   ├── vehicle.dart
│   │   └── Fault.dart
│   ├── service/
│   │   ├── auth_service.dart     # JWT in SharedPreferences
│   │   └── driver_service.dart   # GET /api/drivers
│   └── screens/
│       ├── landing.dart
│       ├── LoginScreen.dart
│       ├── SignUpScreen.dart
│       ├── driver.dart           # Trip sheet + Trip model
│       ├── driver_list_screen.dart
│       ├── driver_service.dart   # Duplicate of service/driver_service.dart
│       └── admin/
│           ├── admin.dart
│           ├── customers.dart
│           ├── load.dart
│           ├── driver.dart
│           └── vehicle.dart
├── test/
│   ├── widget_test.dart          # Default counter test (not updated for this app)
│   └── assigned_loads_test.dart  # Driver trip sheet / assigned loads / weighbridge
├── pubspec.yaml
└── README.md
```

`android/lib/` and `windows/lib/` may still contain **stale copies** of some Dart sources. They are not what `flutter run` compiles. Edit `logistics_app/lib/` only. The old one-shot `android/lib/screens/driver.dart` and `windows/lib/screens/driver.dart` duplicates were removed.

---

## Data models

### Customer

`id?`, `name`, `email`, `contact`, `address`

### Driver

`id?`, `username`, `password`, `email`, `name`, `lastName`, `address`, `licenseNumber`, `nextOfKin`, `nextOfKinContact`, `mobileNumber`, `idNumber`

### Load

`id?`, `customerId?`, `driverId?`, `customerName?`, `description`, `weight`, `pickupLocation`, `deliveryLocation`, `status`, `cargoType`, `actualWeight`  
`fromJson` also reads nested `customer` / `driver` objects and `cargo_type` / `loadType` / `actual_weight`.  
`isBulk` / `needsWeighbridge` drive the driver weighbridge field (`BULK` and no `actualWeight` yet). **BAGGED** never shows that field.

### Vehicle

`id?`, `licensePlate`, `make`, `model`, `year`, `color`, `active`, `lastServiceDate?`, `faults?`, `latitude?`, `longitude?`  
`toJson` omits faults (managed on a separate endpoint).

### Fault

`id?`, `description`, `reportDate?`, `resolved`

### Trip (defined in `screens/driver.dart`, not `classes/`)

`id?`, `dateTime`, `startingMillage`, `endingMillage`, `fuelLitres`, `trailer1`, `trailer2`, `plateNumber`, `driverId`, `loadId`, `customerId`, `status`, `legType`  
`fromJson` accepts nested `driver` / `load` / `customer` ids and both `startMileage` / `startingMillage` (and the same pair for end). There is no `destination` field.

---

## API reference (client)

Base: `http://192.168.32.85:8080`

Authenticated calls send `Authorization: Bearer <jwt>` and usually `Content-Type: application/json`.

| Method | Path | Used by | Success |
|--------|------|---------|---------|
| `POST` | `/api/auth/signup` | Sign up | `200` |
| `POST` | `/api/auth/login` | Login | `200` + `{ token, role }` |
| `GET` | `/api/drivers` | Admin drivers, assign-driver picker, `fetchDrivers()` | `200` |
| `POST` | `/api/drivers` | Add driver | `200` |
| `DELETE` | `/api/drivers/{id}` | Delete driver | `204` |
| `GET` | `/api/customers` | Customers list, load form | `200` |
| `POST` | `/api/customers` | Add customer | `200` / `201` |
| `GET` | `/api/customers/{id}` | Customer details (and current “delete”) | `200` |
| `GET` | `/api/loads` | Loads list | `200` |
| `POST` | `/api/loads` | Create load | `200` / `201` |
| `DELETE` | `/api/loads/{id}` | Delete load | `200` |
| `PATCH` | `/api/loads/{id}/actual-weight` | Driver BULK weighbridge `{ actualWeight }` | `200` / `201` / `204` |
| `GET` | `/api/drivers/me/assigned-loads` | Driver assigned loads | `200` or `204` |
| `GET` | `/api/drivers/me/assigned-vehicle` | Driver assigned vehicle | `200`, `204`, or `404` |
| `GET` | `/api/drivers/me/active-trip` | Restore in-progress trip | `200` or empty |
| `GET` | `/api/vehicles` | Vehicles list (Dio) | `200` |
| `POST` | `/api/vehicles` | Add vehicle | `200` / `201` |
| `PUT` | `/api/vehicles/{id}` | Update vehicle | `200` |
| `DELETE` | `/api/vehicles/{id}` | Delete vehicle | `200` / `204` |
| `GET` | `/api/vehicles/{id}/faults` | Faults dialog | `200` |
| `PUT` | `/api/vehicles/{id}/assign-driver` | Body `{ driverId }` | `200` |
| `POST` | `/api/driver-trips/deadhead-start` | Start empty leg | `200` / `201` |
| `POST` | `/api/driver-trips/deadhead-end` | Arrive at pickup | `200` / `201` |
| `POST` | `/api/driver-trips/loaded-trip-end` | Complete delivery | `200` / `201` |
| WS | `/ws` | Vehicle GPS | `{ vehicleId, latitude, longitude }` |

---

## Authentication

`AuthService` (`lib/service/auth_service.dart`):

- **Save:** `SharedPreferences` key `jwt_token`
- **Read:** `getToken()`
- **Current user:** decode JWT with `jwt_decoder`; user id from `id`, `userId`, `sub`, or `user_id`

There is no logout, token refresh, or expiry check before requests (`isExpired` is only printed).

---

## Realtime vehicle location

`VehiclesPage` opens `IOWebSocketChannel` to `ws://192.168.32.85:8080/ws` with the Bearer token. Incoming JSON updates `Vehicle.latitude` / `longitude` in the in-memory list. Connection is closed in `dispose`. `socket_io_client` is in `pubspec.yaml` and imported but unused; the live path is `web_socket_channel`.

---

## Dependencies

From `pubspec.yaml`:

| Package | Role |
|---------|------|
| `http` | Most REST calls |
| `dio` | Vehicle REST |
| `shared_preferences` | JWT storage |
| `jwt_decoder` | Token decode / user id |
| `intl` | Date formatting / pickers |
| `icons_plus` | Extra icons (admin) |
| `web_socket_channel` | Vehicle GPS |
| `socket_io_client` | Declared, unused |
| `provider` | Declared, unused |
| `cupertino_icons` | iOS-style icons |

Dev: `flutter_test`, `flutter_lints`.

---

## Platform notes

| Platform | Notes |
|----------|--------|
| **Android** | `applicationId`: `com.example.logistics_app`. INTERNET is in debug/profile manifests only. Cleartext HTTP may need `android:usesCleartextTraffic="true"` for release. |
| **iOS** | Display name “Logistics App”. No ATS exception for HTTP; device calls to `http://` may fail unless ATS is relaxed. |
| **Windows** | Supported via `windows/`. |
| **Web** | `web/manifest.json` still says “A new Flutter project.” Mixed-content rules apply if the page is HTTPS and the API is HTTP. |

---

## Known gaps

Documented so the README matches the code:

1. **Backend host** is duplicated, not centralized.
2. **OFFICE / MECHANIC** can sign up but cannot log in to a screen.
3. **Trailers** and **Orders** are UI stubs.
4. **Admin load create** does not set `cargoType`; BULK vs BAGGED (and the weighbridge field) depend on the backend payload on assigned loads.
5. **Customer delete** uses GET, not DELETE.
6. **`DriverListScreen`** and `fetchDrivers()` are unused by routing.
7. **`test/widget_test.dart`** is still the default counter test (`const MyApp()` but `MyApp` has no `const` constructor). Driver trip-sheet coverage lives in `test/assigned_loads_test.dart`.
8. **Stale Dart copies** may still exist under `android/lib` and `windows/lib` (not compiled). The old one-shot `driver.dart` duplicates were deleted.
9. **No logout**, session timeout, or token refresh.
10. **GPS** is stored on the vehicle model but not shown on a map.
11. **`provider`** is unused; screens talk to HTTP directly.
12. Loaded-trip-end sends `fuelLitres`; if the backend DTO is `dieselLitres`, that still needs aligning.

---

## License

Private package (`publish_to: 'none'`). Not published to pub.dev.
