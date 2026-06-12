# ShowSnap

ShowSnap is a full-featured Flutter mobile ticket-booking app (iOS + Android) modelled after BookMyShow.

## Architecture

| Layer | Technology |
|---|---|
| UI | Flutter 3 / Dart |
| State | Riverpod 2.x (manual providers, no codegen) |
| Navigation | GoRouter with role-based redirects |
| Database | Firebase Realtime Database (RTDB) |
| Auth | Firebase Auth (email / password) |
| Media | Cloudinary (unsigned upload preset from app) |
| Payments | Razorpay Flutter SDK |
| Push | Firebase Cloud Messaging |
| Backend | Firebase Cloud Functions (Node 20) |

## User Roles

| Role | Access |
|---|---|
| **End User / Influencer** | Browse movies, book tickets, submit ad requests, view rewards |
| **Theater Manager** | Manage screens, seat layouts, movies, shows, scan QR tickets |
| **Admin** | Full access — users, bookings audit, milestone offers, coupon codes, ad requests |

## Key Features

- **Real-time seat selection** — RTDB transactions with 8-minute TTL lock; expired locks released by Cloud Function every minute
- **Personalized home feed** — affinity scoring based on past booking genres
- **QR e-tickets** — generated with `qr_flutter`, saveable and shareable
- **Milestone rewards** — Cloud Function evaluates unlock thresholds on every booking
- **Coupon codes** — percentage / flat discount with eligibility rules
- **Seat Layout Editor** — 20×20 interactive grid for Theater Managers with category colors
- **QR ticket scanner** — mobile_scanner-based redemption in TM module
- **Ad request pipeline** — 3-step influencer form, admin review with approve/reject + note

## Getting Started

### 1. Prerequisites

```
flutter 3.x
node 20+
firebase-cli
```

### 2. Android setup

Place your `google-services.json` (from Firebase console project **showsnap-2**) at:
```
android/app/google-services.json
```

### 3. iOS setup

Place `GoogleService-Info.plist` at:
```
ios/Runner/GoogleService-Info.plist
```

### 4. Razorpay

Replace `rzp_test_REPLACE_WITH_YOUR_KEY` in [lib/core/config/env.dart](lib/core/config/env.dart) with your Razorpay test key.

### 5. Flutter dependencies

```bash
flutter pub get
```

### 6. Deploy Firebase rules and functions

```bash
firebase deploy --only database
firebase functions:config:set \
  cloudinary.cloud_name="dfvoosm9v" \
  cloudinary.api_key="329914567685393" \
  cloudinary.api_secret="YOUR_CLOUDINARY_API_SECRET"
firebase deploy --only functions
```

### 7. Run

```bash
flutter run
```

## Project Structure

```
lib/
  core/
    config/          # theme, router, env constants
    constants/       # RTDB paths, roles, FCM types
    models/          # 12 data models
    services/        # auth, database, cloudinary, notification, location
    utils/           # extensions, validators
  features/
    auth/            # login, register, profile setup
    home/            # home feed (affinity scoring), search
    movies/          # movie detail, show selection, seat map + selection
    events/          # event detail
    checkout/        # order summary, Razorpay, QR e-ticket
    bookings/        # my bookings list
    theater_manager/ # TM dashboard, screens, seat layout editor,
                     # movie manager, show scheduler, ticket scanner
    influencer/      # 3-step ad request form
    admin/           # dashboard, user management, ticket audit,
                     # milestone offers, coupon codes, ad requests
firebase/
  database.rules.json  # RTDB security rules
functions/
  index.js             # 5 Cloud Functions
```

## Cloud Functions

| ID | Trigger | Purpose |
|---|---|---|
| CF-01 `releaseSeatLocks` | Pub/Sub every 1 min | Release expired 8-min seat locks |
| CF-02 `evaluateMilestones` | RTDB booking write | Unlock milestone rewards |
| CF-03 `getCloudinarySignature` | HTTPS callable | Signed upload params (admin/TM only) |
| CF-04 `onBookingCancelled` | RTDB status change | Release seats, update seatsAvailable |
| CF-05 `sendShowReminders` | Pub/Sub every 60 min | FCM push 2 h before show |

## Security Notes

- Cloudinary API secret is **never** stored in the Flutter app — only in Cloud Functions config
- RTDB rules enforce per-user read/write, TM scope to own theater, admin full access
- App uses unsigned Cloudinary upload preset (`ml_default`) — no server-side signing needed for standard uploads
- Razorpay key ID is compile-time constant; payment verification done before confirming booking

## Tests

```bash
flutter test
```

---

## V2 — Interactive Polish & User Dashboard

V2 builds on top of the V1 feature-complete app to add animation, delight, and a full user analytics dashboard.

### What's new in V2

| Feature | Details |
|---|---|
| **Design tokens** | `ShowSnapRadius` (25px primary), `ShowSnapShadow`, `ShowSnapDuration` |
| **Splash screen** | Logo elastic entrance, tagline, loading bar, smart routing |
| **Onboarding** | 3-page PageView with WormEffect indicator and staggered animations |
| **Auth screens** | Gradient header, animated logo pulse, shake-on-error, password strength bar, match indicator |
| **Movie detail** | Hero poster transition, animated star rating, expandable synopsis, staggered content |
| **Seat selection** | Animated screen bar (elasticOut), staggered seat rows, bounce-on-select, color-coded TTL timer |
| **Ticket screen** | Ticket-stub design with dashed divider + circle cutouts, confetti burst, 3-button row |
| **User Dashboard** | Count-up stat grid, fl_chart BarChart (spending) + RadarChart (genres), milestone progress, staggered booking list |
| **TappableScale** | 0.95 scale + haptic feedback on all interactive cards |
| **ShowSnapToast** | Overlay toast system (slide from bottom, colored border, progress bar) |
| **Skeleton loading** | Shimmer-based placeholders for movie cards, shows, bookings, stat cards |
| **Page transitions** | SharedAxisTransition (horizontal/vertical) + FadeScaleTransition via GoRouter |
| **Home feed** | Staggered section entrances (150ms apart) |
| **In-app FCM banner** | Slides from top, yellow left border, 3-second auto-dismiss |

### New packages (V2)

```
flutter_animate: ^4.5.2
animations: ^2.0.11
smooth_page_indicator: ^1.2.0+3
confetti: ^0.8.0
flutter_staggered_animations: ^1.1.1
fl_chart: (already in V1)
```

### Documentation

- [DECISIONS_V2.md](DECISIONS_V2.md) — architecture & design rationale
- [ANIMATION_GUIDE.md](ANIMATION_GUIDE.md) — animation patterns and code examples
