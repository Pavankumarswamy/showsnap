# ShowSnap — Autonomous Overnight Build Prompt
### For Claude (claude.ai / Projects) — Developer is unavailable. Work end-to-end without interruption.

---

## 🔐 Access Tokens & Credentials — Set These Before Starting

Before writing a single line of code, read this section completely.  
All secrets go in `lib/core/config/env.dart` (gitignored) and `firebase/.env`.

| Service | Where to get | Variable name |
|---|---|---|
| Firebase — `google-services.json` | Firebase Console → Project Settings → Android App | Place at `android/app/google-services.json` |
| Firebase — `GoogleService-Info.plist` | Firebase Console → Project Settings → iOS App | Place at `ios/Runner/GoogleService-Info.plist` |
| Cloudinary Cloud Name | cloudinary.com → Dashboard | `CLOUDINARY_CLOUD_NAME` |
| Cloudinary Upload Preset (unsigned) | cloudinary.com → Settings → Upload Presets | `CLOUDINARY_UPLOAD_PRESET` |
| Firebase Project ID | Firebase Console | `FIREBASE_PROJECT_ID` |
| Razorpay Key ID (test mode) | razorpay.com → Dashboard → API Keys | `RAZORPAY_KEY_ID` |

> **IMPORTANT**: Never hardcode secrets in Dart source files. Use `flutter_dotenv` or compile-time `const String.fromEnvironment()`.

---

## 🧠 Project Summary (Read This First — Understand Before Coding)

**ShowSnap** is a mobile ticket-booking app (like BookMyShow) built with:
- **Frontend**: Flutter 3 (Dart) — iOS + Android
- **Backend**: Firebase (Auth + Realtime Database + Cloud Functions + Cloud Messaging)
- **Media**: Cloudinary (posters, banners, ad creatives, e-tickets)
- **Theme**: White background, yellow (#F5A800) to light-yellow (#FFF176) gradient, green (#43A047) accents

### Three User Roles
1. **Admin** — full platform control
2. **Theater Manager (TM)** — manages one theater (screens, shows, bookings)
3. **End User / Influencer** — books tickets, submits ad requests

### Core Features
- Movie + Event ticket booking with real-time seat maps
- Interactive seat layout (grid array: x/y coordinates per seat)
- Seat locking (8-min TTL via Firebase RTDB transactions)
- Admin: ticket management, offer/coupon engine, ad request approvals
- Personalised home feed (affinity scoring from booking history)
- Milestone rewards (e.g., 9 unique movies → 10th ticket free)
- Push notifications via FCM

---

## 📋 Instructions for Claude (Autonomous Mode)

You are building this entire app while the developer sleeps.  
**Rules:**
1. Do NOT ask clarifying questions. Make reasonable decisions and document them in `DECISIONS.md`.
2. Work step by step through every phase below. Do not skip phases.
3. After each phase, write a brief `## Phase N Complete` note in `BUILD_LOG.md`.
4. Use maximum context — write complete files, not stubs or placeholders.
5. If you hit a token limit mid-phase, finish the current file cleanly, commit the log, and continue in the next message.
6. Prioritise correctness over speed. Compile errors are unacceptable.
7. Write `// TODO: [description]` only for payment gateway wiring (requires live credentials). Everything else must be complete.

---

## 🏗️ Phase 1 — Project Scaffolding

**Goal**: Create a clean Flutter project with all dependencies and folder structure.

### 1.1 Create Flutter Project
```bash
flutter create showsnap --org com.tenx --platforms android,ios
cd showsnap
```

### 1.2 pubspec.yaml — Add All Dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
  # Firebase
  firebase_core: ^latest
  firebase_auth: ^latest
  firebase_database: ^latest
  firebase_messaging: ^latest
  firebase_analytics: ^latest
  # Media
  cloudinary_flutter: ^latest
  cloudinary_url_gen: ^latest
  image_picker: ^latest
  # Navigation
  go_router: ^latest
  # State
  flutter_riverpod: ^latest
  riverpod_annotation: ^latest
  # Payment
  razorpay_flutter: ^latest
  # QR
  qr_flutter: ^latest
  mobile_scanner: ^latest
  # Utils
  intl: ^latest
  shared_preferences: ^latest
  flutter_dotenv: ^latest
  uuid: ^latest
  cached_network_image: ^latest
  shimmer: ^latest
  share_plus: ^latest
  path_provider: ^latest
  permission_handler: ^latest
  geolocator: ^latest
  geocoding: ^latest

dev_dependencies:
  build_runner: ^latest
  riverpod_generator: ^latest
  flutter_lints: ^latest
```

### 1.3 Folder Structure
Create this exact structure:
```
lib/
├── core/
│   ├── config/
│   │   ├── env.dart              # secrets (gitignored)
│   │   ├── theme.dart            # ShowSnap color theme
│   │   └── router.dart           # GoRouter config
│   ├── constants/
│   │   └── app_constants.dart
│   ├── services/
│   │   ├── auth_service.dart
│   │   ├── database_service.dart
│   │   ├── cloudinary_service.dart
│   │   ├── notification_service.dart
│   │   └── location_service.dart
│   ├── models/                   # All data models
│   └── utils/
│       ├── extensions.dart
│       └── validators.dart
├── features/
│   ├── auth/
│   │   ├── screens/
│   │   │   ├── login_screen.dart
│   │   │   ├── register_screen.dart
│   │   │   └── profile_setup_screen.dart
│   │   └── providers/
│   │       └── auth_provider.dart
│   ├── home/
│   │   ├── screens/
│   │   │   └── home_screen.dart
│   │   ├── widgets/
│   │   │   ├── movie_card.dart
│   │   │   ├── carousel_section.dart
│   │   │   └── event_card.dart
│   │   └── providers/
│   │       └── home_provider.dart
│   ├── movies/
│   │   ├── screens/
│   │   │   ├── movie_detail_screen.dart
│   │   │   ├── show_selection_screen.dart
│   │   │   └── seat_selection_screen.dart
│   │   ├── widgets/
│   │   │   └── seat_map_widget.dart
│   │   └── providers/
│   │       └── booking_provider.dart
│   ├── events/
│   │   ├── screens/
│   │   │   └── event_detail_screen.dart
│   │   └── providers/
│   ├── checkout/
│   │   ├── screens/
│   │   │   ├── order_summary_screen.dart
│   │   │   └── ticket_screen.dart
│   │   └── providers/
│   ├── bookings/
│   │   ├── screens/
│   │   │   └── my_bookings_screen.dart
│   │   └── providers/
│   ├── admin/
│   │   ├── screens/
│   │   │   ├── admin_dashboard_screen.dart
│   │   │   ├── user_management_screen.dart
│   │   │   ├── ticket_audit_screen.dart
│   │   │   ├── offers_screen.dart
│   │   │   └── ad_requests_screen.dart
│   │   └── providers/
│   ├── theater_manager/
│   │   ├── screens/
│   │   │   ├── tm_dashboard_screen.dart
│   │   │   ├── screen_manager_screen.dart
│   │   │   ├── seat_layout_editor_screen.dart
│   │   │   ├── movie_manager_screen.dart
│   │   │   └── show_scheduler_screen.dart
│   │   └── providers/
│   └── influencer/
│       ├── screens/
│       │   └── ad_request_form_screen.dart
│       └── providers/
└── main.dart
```

---

## 🎨 Phase 2 — Theme & Design System

**File**: `lib/core/config/theme.dart`

Build the complete `ThemeData` with:
- Primary: `#F5A800` (amber/gold)
- Secondary: `#43A047` (green)
- Background: `#FFFFFF`
- AppBar gradient: `LinearGradient([#F5A800, #FFD000])`
- Button style: yellow fill, black text, rounded-12
- Card style: white with subtle shadow, 12px radius
- Text theme: `Poppins` or `Nunito` (use GoogleFonts)
- Custom seat color constants: available=white, selected=`#F5A800`, booked=grey, accessible=`#1565C0`

---

## 🔑 Phase 3 — Firebase Setup & Security Rules

### 3.1 Firebase Initialization
`lib/main.dart` — init Firebase before `runApp`, setup FCM background handler.

### 3.2 Firebase RTDB Security Rules
Write complete rules (`firebase/database.rules.json`):
- `/users/{uid}` — read/write own only; admin read-all
- `/theaters/**` — TM write own theater only; users read-only
- `/shows/{showId}/seats/{seatId}` — authenticated users can run lock transaction; only Cloud Function can set `booked`
- `/bookings/{bookingId}` — owner and admin read; Cloud Function write
- `/coupons/**` — admin write; authenticated read
- `/offers/**` — admin write; authenticated read
- `/adRequests/**` — influencer write own; admin read-all + write status

### 3.3 Auth Service
`lib/core/services/auth_service.dart`:
- `signInWithEmail`, `signInWithGoogle`, `signUpWithEmail`
- `sendPasswordReset`, `signOut`
- `getCurrentUserRole()` — reads `/users/{uid}/role` from RTDB
- Stream `authStateChanges` exposed via Riverpod provider

---

## 📦 Phase 4 — Data Models

Build complete Dart model classes with `fromJson`/`toJson` for every entity:

### Models to build (`lib/core/models/`):
1. **UserModel** — uid, displayName, email, phone, city, avatarUrl, role, preferences, affinityScores, rewards, totalUniqueMoviesBooked
2. **TheaterModel** — theaterId, name, city, address, lat, lng, logoUrl, contactPhone, managerId, isActive
3. **ScreenModel** — screenId, theaterId, name, position, technology, totalSeats, seatLayout (List<SeatModel>), isUnderMaintenance
4. **SeatModel** — seatId, row, number, category (enum: Silver/Gold/Platinum), x, y, isAccessible
5. **MovieModel** — movieId, title, language, genres, duration, releaseDate, certificate, synopsis, cast, director, posterUrl, trailerUrl, status, addedByTm
6. **ShowModel** — showId, movieId, theaterId, screenId, startTs, endTs, pricing (Map<category, price>), bookingOpen, seats (Map<seatId, SeatStatusModel>), seatsAvailable
7. **SeatStatusModel** — status (enum: available/locked/booked), lockedBy, lockedAt
8. **BookingModel** — bookingId, uid, showId, movieId, theaterId, screenId, seats, totalAmount, couponCode, discountApplied, status, eTicketUrl, paymentTxnId, createdAt
9. **EventModel** — eventId, name, organizer, venueId, startTs, endTs, category, description, posterUrl, ticketTiers
10. **CouponModel** — code, discountType, discountValue, maxUses, currentUses, expiryTs, minOrderValue, eligibleCategories, isActive
11. **OfferModel** — offerId, milestoneType, threshold, rewardType, rewardValue, validityDays, isActive
12. **AdRequestModel** — requestId, uid, brandName, campaignTitle, targetTheaters, targetScreens, creativeUrls, startDate, endDate, budget, status, adminNote

---

## 🔧 Phase 5 — Core Services

### 5.1 DatabaseService (`lib/core/services/database_service.dart`)
Complete RTDB wrapper with methods for every CRUD operation across all collections.  
Key methods:
- `streamShow(showId)` — real-time show stream
- `lockSeat(showId, seatId, uid)` — RTDB transaction with optimistic lock
- `confirmBooking(bookingId, booking)` — atomic: set booking + mark seats booked + decrement seatsAvailable
- `releaseExpiredLocks(showId)` — sweep locked seats > 8 min (called from Cloud Function too)
- `getUserBookingHistory(uid)` — returns confirmed+redeemed bookings for personalisation
- `validateCoupon(code, orderValue, category)` — validates and returns discount or throws

### 5.2 CloudinaryService (`lib/core/services/cloudinary_service.dart`)
- `uploadImage(File file, folder)` — upload to Cloudinary, return secure URL
- `uploadVideo(File file, folder)` — for ad creatives
- Use unsigned upload preset (credentials from env.dart)

### 5.3 NotificationService (`lib/core/services/notification_service.dart`)
- FCM setup, request permissions
- `subscribeToTopic`, `sendLocalNotification`
- Handle foreground + background + terminated app message scenarios

---

## 🏠 Phase 6 — Home Screen & Personalisation

### 6.1 PersonalisationProvider
Reads user's `affinityScores` and `bookingHistory` from RTDB.  
Computes ranked movie list:
```
score = (genreAffinity × 0.5) + (recencyBoost × 0.3) + (trendingScore × 0.2)
```
Cold start: use signup genre preferences + city-level trending.

### 6.2 HomeScreen
Scrollable screen with these sections (each a horizontal `ListView`):
1. **Recommended for You** — personalised ranked movies
2. **Now Showing** — all active movies
3. **Upcoming** — releaseDate > today
4. **Events Near You** — geolocation-sorted events
5. **Trending This Week** — top 10 by bookings count (last 7 days)

Each movie/event card: poster (CachedNetworkImage), title, genre chips, rating, "Book" button.

### 6.3 Search
Full-text search across movies, events, theaters using RTDB `orderByChild` queries.  
Filter chips: genre, language, date, city, price range, certificate.

---

## 🎬 Phase 7 — Movie Booking Flow

### 7.1 MovieDetailScreen
Full poster hero, trailer WebView, synopsis, cast horizontal scroll, certificate badge.  
"Book Tickets" CTA → triggers date picker → theater list → show time grid.

### 7.2 ShowTimeScreen
Date selector (horizontal scroll, next 7 days).  
Per-theater: name, distance, show time buttons color-coded:
- Green: > 20% available
- Yellow: ≤ 20% available  
- Grey: sold out (seatsAvailable == 0)
- Red: bookingOpen == false

### 7.3 SeatSelectionScreen + SeatMapWidget
**This is the most complex screen — implement it completely.**

`SeatMapWidget` renders the seat grid from `screen.seatLayout[]` using `x`/`y` coordinates on a custom `CustomPaint` or `GridView`.

On screen open: subscribe to `streamShow(showId)` — seats update live.

Seat tap logic:
1. Check seat status in real-time stream
2. If available: call `lockSeat(showId, seatId, uid)` RTDB transaction
3. If transaction succeeds: add to selected list, show 8-min countdown
4. If transaction fails (race): show "Just taken" snackbar
5. Tap again to unlock (release transaction)

Selected seats panel at bottom: list of selected seats, category, price per seat, subtotal.  
Max 6 seats per transaction. "Proceed" button → OrderSummaryScreen.

TTL timer: if 8 minutes elapse before payment, auto-release all locks + navigate back with alert.

---

## 🛒 Phase 8 — Checkout

### 8.1 OrderSummaryScreen
Show: movie name, date/time, theater, screen, selected seats table (seatId | category | price).  
Subtotal, convenience fee (₹20 flat per booking), coupon field, total.

Coupon validation:
- Call `validateCoupon(code, orderValue, category)`
- If valid: show discount line, update total
- If invalid: show error message

Milestone reward: auto-fetch from `/users/{uid}/rewards/` — if unused reward exists matching this booking's category, show "Apply Reward" button.

### 8.2 Payment
Initiate Razorpay checkout with order amount.  
On `paymentSuccess`: call `confirmBooking(...)` Cloud Function or direct RTDB atomic write.  
On `paymentError`: release all seat locks, show error.  
On `paymentCancelled`: release all seat locks, return to seat selection.

### 8.3 TicketScreen
After confirmed booking: show e-ticket UI.
- QR code (`qr_flutter`) encoding the bookingId
- Movie name, date/time, theater, screen, seat list
- "Download" button → save as image using `RepaintBoundary` + `path_provider`
- "Share" button → `share_plus`

---

## 🎭 Phase 9 — Theater Manager Module

### 9.1 TM Dashboard
Stats cards: today's shows, total seats sold, revenue today.  
Quick actions: Add Show, Add Movie, Manage Screens.

### 9.2 ScreenManagerScreen
List of screens for the TM's theater.  
Add screen form: name, position, technology (dropdown), total seats.  
Each screen card: name, capacity, status badge, "Edit Layout" and "Manage Shows" buttons.

### 9.3 SeatLayoutEditorScreen
**Complex UI — implement fully.**

Grid editor where TM places seats:
- Grid of 20×20 cells
- Tap cell to add a seat; configure: row letter, number, category (Silver/Gold/Platinum), isAccessible
- Drag to reposition
- Save outputs the `seatLayout` JSON array to RTDB
- Preview mode shows the layout as users will see it

### 9.4 MovieManagerScreen
List of movies added by this TM.  
"Add Movie" form — all fields from MovieModel — with Cloudinary poster upload.  
"Close Movie" action with confirmation dialog.

### 9.5 ShowSchedulerScreen
Weekly grid calendar showing all shows by screen.  
"Add Show" bottom sheet: select movie, screen, date, start time, pricing per category.  
Conflict detection: if new show overlaps existing show on same screen, block with error message.

### 9.6 Ticket Scanning
QR scanner screen (mobile_scanner). On scan: parse bookingId, fetch booking, mark as `redeemed`, show green checkmark + seat/user info.

---

## 👑 Phase 10 — Admin Module

### 10.1 Admin Dashboard
Stats grid: total users, today's bookings, total revenue, pending ad requests.  
Charts using `fl_chart`: bookings over last 30 days (line), revenue by theater (bar).

### 10.2 UserManagementScreen
Paginated list of all users with search + role filter.  
Each row: avatar, name, email, role badge, status badge.  
Actions: deactivate/reactivate, change role, reset password.

### 10.3 TicketAuditScreen
Global booking ledger with filters: date range, theater, status.  
"Mark Redeemed" button per confirmed ticket.  
Export CSV button (generates CSV string, shares via `share_plus`).

### 10.4 OffersScreen
Two tabs: Milestone Offers | Coupon Codes.

**Milestone Offer form**:
- milestoneType dropdown (unique_movies / total_bookings)
- threshold (number input)
- rewardType (free_ticket / percent_discount / flat_discount)
- rewardValue, validityDays
- Toggle active/inactive

**Coupon form**:
- code (string), discountType, discountValue
- maxUses, expiryDate, minOrderValue, eligibleCategories (multi-select)

### 10.5 AdRequestsScreen
List of pending/approved/rejected requests.  
Pending tab: creative image preview, campaign details, Approve/Reject buttons.  
Approve: set schedule (start/end date + target theater/screen).  
Reject: optional feedback note field.

---

## 📣 Phase 11 — Influencer Module

### Ad Request Form Screen
Multi-step form:
1. Brand & Campaign info (name, title, description)
2. Target (multi-select theaters and screens)
3. Schedule (date range, preferred slots)
4. Creative upload (image/video via Cloudinary)
5. Budget range (dropdown)
6. Review & Submit

Submit → write to `/adRequests/{uuid}` with status `pending`.  
My Requests screen: list of submitted requests with status badges.

---

## 🔔 Phase 12 — Notifications

Set up FCM complete:
1. Foreground: show in-app snackbar/banner via `OverlayEntry`
2. Background/terminated: tap opens relevant screen via `GoRouter` deep link

Notification types to handle:
- `booking_confirmed` → open TicketScreen
- `show_reminder` → open movie/event detail
- `reward_unlocked` → open My Rewards
- `ad_request_status` → open Ad Requests
- `promo` → open Home

---

## ⚡ Phase 13 — Firebase Cloud Functions

Write Node.js v2 Cloud Functions in `functions/index.js`:

### CF-01: `releaseSeatLocks`
Scheduled every 5 minutes.  
Scans all active shows for locked seats with `lockedAt < now - 8min`.  
Sets status back to `available`, clears lockedBy/lockedAt.

### CF-02: `evaluateMilestones`
Triggered on `/bookings/{bookingId}` create.  
Reads user's confirmed bookings, counts unique movieIds in active milestone period.  
If threshold met: creates reward in `/users/{uid}/rewards/`, sends FCM notification.

### CF-03: `getCloudinarySignature`
HTTP callable function.  
Accepts `folder`, `publicId`.  
Returns Cloudinary signed upload params using API secret.  
This is the ONLY place the Cloudinary API secret exists.

### CF-04: `onBookingCancelled`
Triggered on `/bookings/{bookingId}/status` update to `cancelled`.  
Releases booked seats back to `available`.  
Updates `seatsAvailable` counter.

### CF-05: `sendShowReminder`
Scheduled hourly.  
Finds shows starting in 2 hours.  
Sends FCM to all confirmed bookers for those shows.

---

## 🧪 Phase 14 — Testing & Polish

### 14.1 Write widget tests for:
- SeatMapWidget — renders grid correctly from seatLayout array
- OrderSummaryScreen — coupon validation UI
- HomeScreen — carousel renders with mock data

### 14.2 Integration test flow:
1. Register user → set preferences → verify home feed loads
2. Select movie → select show → select seats → lock seats → cancel → verify seats released
3. Admin creates coupon → user applies at checkout → verify discount

### 14.3 Polish checklist:
- [ ] All screens have loading shimmer states
- [ ] All async calls have error handling with user-facing snackbars
- [ ] Empty states for all lists (no movies, no bookings, etc.)
- [ ] Pull-to-refresh on home feed and booking list
- [ ] Keyboard dismiss on tap outside (GestureDetector wrapping scrollviews)
- [ ] All images use CachedNetworkImage with placeholder
- [ ] Deep links work for ticket sharing
- [ ] App handles no-internet gracefully with a banner
- [ ] Accessibility: all interactive elements have semantic labels

---

## 📝 Phase 15 — Documentation

Create `README.md` with:
- Project overview
- Setup instructions (Firebase config, env.dart setup, Cloudinary upload preset)
- Folder structure explanation
- Running the app (flutter run)
- Running Cloud Functions locally (firebase emulators:start)

Create `DECISIONS.md` documenting all architectural choices made autonomously.

Create `BUILD_LOG.md` with completion status of each phase.

---

## ✅ Completion Criteria

The build is complete when:
- [ ] `flutter analyze` reports zero errors
- [ ] All 15 phases are marked complete in BUILD_LOG.md
- [ ] App launches on both Android and iOS simulators
- [ ] All 3 user roles can log in and access their respective dashboards
- [ ] Seat selection screen shows live updates when seats are locked by another session (test with 2 simulators)
- [ ] Admin can create a milestone offer and a user can redeem it
- [ ] E-ticket generates and displays QR code correctly

---

*Prompt authored by 10X Technologies — Pavan + Venkat Malla*  
*ShowSnap SRS v1.0 — Full tech stack: Flutter + Firebase RTDB + Cloudinary*
