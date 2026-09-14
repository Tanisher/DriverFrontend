# What this application is supposed to be

This is not a finished product. It is a mid-build **fleet logistics operations app**: a digital operations desk for a haulage company, plus a trip sheet in the driver’s phone.

The repo is named `DriverFrontend`, the Flutter package is `logistics_app`, and the landing copy says “Manage your trips and logistics.” Taken together, the intended system is:

> Office staff book work against customers. Loads move on trucks and trailers. Drivers record each run (mileage, diesel, trailers, and a weighbridge reading for bulk). Admins see the fleet. Mechanics deal with faults. Someone in the office can watch where a truck is.

That is a standard small-fleet TMS (transport management) shape. The code was built toward that, then stopped partway through.

---

## The business this was meant to serve

A company that:

- Has **customers** (who they haul for)
- Moves **loads** (pickup → delivery, weight, status)
- Runs **vehicles** (trucks) and **trailers**
- Employs **drivers** (licence, next of kin, ID — typical African/SA haulage HR, not a toy “name + email” model)
- Takes **orders** (the commercial request before a load is on the road)
- Tracks **faults** (breakdowns / workshop)
- Wants **live GPS** on vehicles

The driver screen is a **trip sheet**, not a consumer maps app. The sheet is now a two-leg run against an assigned load:

| Paper field | In the app |
|-------------|------------|
| Vehicle | Read-only assigned plate (`GET /api/drivers/me/assigned-vehicle`) |
| Load / route | Pick from assigned loads (pickup → delivery) |
| Start / end mileage | Numbers; backend `400`/`422` millage errors show on the field |
| Diesel litres | Fuel, on the loaded (delivery) leg |
| Trailers | Trailer 1 and trailer 2, on the loaded leg |
| Weighbridge | **BULK** only — pickup (optional) or delivery (required if still blank) → `PATCH /api/loads/{id}/actual-weight` |

That is the core driver job: run deadhead to pickup, then the loaded leg to delivery, so the office has kilometres, fuel, trailers, and (for bulk) actual weight.

---

## Who was supposed to use it

Signup already lists four roles. Only two have a home screen. The other two look unused; they are more likely **reserved for screens that were next**.

| Role | What the code implies they were for | Built? |
|------|-------------------------------------|--------|
| **ADMIN** | Full operations dashboard | Partially — 4 of 6 sections |
| **DRIVER** | Own trip sheet: two-leg run on an assigned load | Built — assigned load/vehicle, deadhead + loaded, BULK weighbridge; no trip-history list |
| **OFFICE** | Bookings, customers, loads, orders without full admin power | Role exists, no UI |
| **MECHANIC** | Vehicle faults, service dates, workshop | Role exists; fault **model + API** exist on vehicles, no mechanic home |

That pattern is typical: auth and role names land first, then screens per role. OFFICE and MECHANIC were not abandoned ideas — they were queued behind driver + admin.

---

## The product, if it had been finished

A plausible finished version, inferred only from what is already in the tree:

1. **Landing → signup / login** with JWT. Session stays on the device.
2. **Driver** opens a trip sheet, picks a real assigned load, records two trailers on delivery, and (for **BULK**) a weighbridge reading. Trip history list and computed kilometres are still not shown.
3. **Admin / office** runs the company from one dashboard:
   - Customers
   - Orders (commercial) → become Loads (operational)
   - Drivers (HR + accounts)
   - Vehicles (fleet, assign driver, service date, active/inactive)
   - Trailers (couple to trips and trucks)
   - Live positions on vehicles (WebSocket already pushing lat/lng)
4. **Mechanic** sees faults per vehicle, marks them resolved, uses last service date.
5. **Map** — GPS is stored on `Vehicle` but never drawn. The next UI after the socket was almost certainly a map or a live coordinate readout.

Trailers and Orders in the sidebar are not fake menu items. They are **empty slots in a dashboard that was laid out as a whole**, then filled left-to-right: Customers → Loads → Drivers → Vehicles, and then work stopped.

---

## How development actually went

Reading comments, duplicates, unused packages, and which screens are deep vs empty, the build order looks like this.

### 1. Flutter starter

Default README, default counter widget test, `com.example.logistics_app`. The project never got a real product name in the manifests.

### 2. Auth first

Landing, login, signup, `AuthService`, JWT in `SharedPreferences`. Login routes `ADMIN` and `DRIVER` only. Roles were designed wider than the screens that existed.

### 3. A first “list drivers” screen, then dropped

`DriverListScreen` + `fetchDrivers()` + a commented `/home` route. That was an early “can we talk to `/api/drivers`?” spike. The real driver product became the **trip sheet**, and the list was left behind (still imported in `main.dart`).

The same `fetchDrivers` file exists twice (`lib/service/` and `lib/screens/`). Copy-paste while figuring out folders.

### 4. Driver trip sheet — later rewired to the two-leg API

The first pass was a one-shot `POST /api/driver-trips/create` form with hardcoded `loadId: 1` / `customerId: 1`, a destination field, and `GET /api/driver-trips/driver/username/{id}` for a records table. That is gone from compiled `lib/screens/driver.dart` (and the stale `android/` / `windows/` copies of that file were deleted).

The sheet now:

- Loads assigned work and vehicle from `/api/drivers/me/*`
- Restores an in-progress trip from `GET /api/drivers/me/active-trip`
- Posts `deadhead-start` → `deadhead-end` → `loaded-trip-end`
- PATCHes `actual-weight` for **BULK** cargo at pickup or delivery

Admin load create still does not collect `cargoType`; the driver UI trusts whatever the assigned-load payload sends.

### 5. Admin dashboard scaffolded as six modules at once

`admin.dart` still says `// Placeholder Pages for each section`. The rail was designed with **all six destinations** before every page had an API:

Customers, Loads, Drivers, Vehicles, **Trailers**, **Orders**.

Then real pages were extracted into their own files (`customers.dart`, `load.dart`, `driver.dart`, `vehicle.dart`). Trailers and Orders were **never extracted** — they are still inline stubs with “Add Trailer” / “Create Order” buttons that do nothing.

That is what “still in production” looks like: the IA is committed; the last two modules were next.

### 6. CRUD filled in, unevenly

| Module | How far it got |
|--------|----------------|
| Customers | List, add, details. Delete is still a GET (wrong method). Validation written, not called. |
| Loads | List, add (with customer dropdown), delete. No `cargoType` on create; BULK weighbridge is driver-side. |
| Drivers | List, add (full HR form), delete. No edit. |
| Vehicles | The deepest page: add/edit/delete, assign driver, faults, Dio (not `http`), WebSocket GPS. |
| Trailers | Title + dead buttons + FAB. |
| Orders | Same shell. |

Vehicles look like the last thing someone spent real time on. They switched HTTP library (`dio`), tried Socket.IO (`socket_io_client` imported twice, unused), then used raw `web_socket_channel`. Live location updates the model; **there is still no map**. Tracking was started, UI not finished.

Faults on vehicles + a `MECHANIC` role + `lastServiceDate` is the workshop slice, started from the admin vehicle card, not from a mechanic app yet.

### 7. Architecture they meant to add, then skipped

- **`provider`** is in `pubspec.yaml` and never used. Plan: shared auth/fleet state. Reality: every screen hits HTTP itself.
- **`socket_io_client`** vs **`web_socket_channel`**: they started one realtime approach, shipped the other.
- No shared `baseUrl` / `.env`. IP `192.168.32.85:8080` pasted everywhere — local LAN backend during development.

### 8. Messy multi-platform copies

`android/lib/` and `windows/lib/` still hold some duplicate Dart sources; Flutter does not compile them. The old one-shot `screens/driver.dart` copies in those trees were deleted so they would not be edited by mistake.

---

## How to read the “shells”

Do not treat Trailers, Orders, OFFICE, or MECHANIC as fake or cancelled.

Treat them as **the remaining production backlog**, in roughly this order:

1. Admin load create: `cargoType` (BULK / BAGGED) so weighbridge gating is not backend-only.
2. Driver trip history (the old username GET + records table were removed with the one-shot form).
3. **Trailers** admin CRUD (the sidebar slot is waiting).
4. **Orders** admin CRUD, likely feeding Loads.
5. OFFICE home (probably a subset of the admin rail).
6. MECHANIC home (faults + service — API already exists on vehicles).
7. Map / live coordinates from the WebSocket already in `VehiclesPage`.
8. Logout, token expiry, one config for the API host.
9. Fix customer delete; drop the old driver list route.

Until those exist, the app is an **ops console + driver trip sheet**, talking to a backend that was clearly designed for the fuller product (drivers, customers, loads, vehicles, faults, trips, websocket).

---

## One-line verdict

**Intended:** a multi-role haulage TMS (office, drivers, mechanics, live fleet).  
**Actually built:** login, a two-leg driver trip sheet (assigned load/vehicle, deadhead + loaded, BULK weighbridge), and an admin dashboard whose last two modules (trailers, orders) are still empty frames from that same production pass — not decoration.
