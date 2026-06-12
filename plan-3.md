# ShowSnap — V3 Complete User Dashboard
## Full Functional Alignment: BookMyShow-level UX + End-to-End User Flows
### Autonomous Overnight Build Prompt — Continuation of V1 + V2
### Developer is unavailable. Build everything completely. Zero questions.

---

## 🧠 What This Prompt Builds

V3 is the **final functional layer**. V1 built the backend + screens. V2 added animations + polish. V3 **wires every user-facing journey into one cohesive, interactive dashboard** — identical in completeness to BookMyShow but with ShowSnap's yellow/green identity.

Every feature a user can do in ShowSnap must be accessible from the dashboard or home. No dead ends. No placeholder screens. No "Coming Soon" except payment wallet.

---

## 🔐 No New Credentials Needed

All tokens set in V1. Packages from V2 are already installed.

**New packages to add to `pubspec.yaml`**:
```yaml
  webview_flutter: ^latest          # trailer playback
  youtube_player_flutter: ^latest   # YouTube trailer embed
  file_picker: ^latest              # ad creative file upload
  video_player: ^latest             # video ad preview
  flutter_rating_bar: ^latest       # user rating after movie
  timeline_tile: ^latest            # booking journey timeline
  dotted_border: ^latest            # coupon card dashed border
  flutter_slidable: ^latest         # swipeable list actions
  badges: ^latest                   # notification count badges
  animated_bottom_navigation_bar: ^latest  # polished bottom nav
  showcaseview: ^latest             # first-time feature walkthrough
  flutter_typeahead: ^latest        # search autocomplete
  intl_phone_field: ^latest         # phone input with country code
```

Run `flutter pub get` immediately.

---

## 📋 Autonomous Rules (Critical — Read Before Coding)

1. **Never ask questions.** Make sensible decisions. Log everything in `DECISIONS_V3.md`.
2. **Cross-check list is at the end of this prompt.** Every item must pass before marking done.
3. **Every screen must be reachable** from the main nav or dashboard. No orphan screens.
4. **Every form must validate.** No form submits with empty required fields.
5. **Every list must have an empty state.** No blank white screens.
6. **Every destructive action needs a confirmation dialog.**
7. **Every Firebase write must have error handling** — catch the error, show `ShowSnapToast`.
8. **Border radius = 25px everywhere** (from V2). Do not regress this.
9. **Shimmer on every loading state** (from V2). No raw `CircularProgressIndicator`.
10. All `DateTime` displayed as "Wed, 14 Jun • 7:30 PM" format using `intl` package.

---

## 🗺️ Master Navigation Architecture

This is the final navigation tree. Build it exactly.

```
ShowSnap App
├── Splash Screen
├── Onboarding (first-time only)
├── Auth
│   ├── Login
│   ├── Register
│   └── Profile Setup (genres + city)
│
└── Main Shell (BottomNavigationBar — 5 tabs)
    │
    ├── TAB 1: Home
    │   ├── Movie Detail
    │   │   ├── Show Selection (date → theater → time)
    │   │   │   └── Seat Selection
    │   │   │       └── Order Summary
    │   │   │           └── Payment → E-Ticket
    │   └── Event Detail
    │       ├── Ticket Tier Selection
    │       └── Order Summary → Payment → E-Ticket
    │
    ├── TAB 2: Explore
    │   ├── Movies (filter/sort)
    │   ├── Events (filter/sort)
    │   ├── Theaters (map/list)
    │   └── Search Results
    │
    ├── TAB 3: My Bookings
    │   ├── Upcoming Tab
    │   │   └── Booking Detail → E-Ticket
    │   └── Past Tab
    │       └── Rate Movie (post-show)
    │
    ├── TAB 4: Offers
    │   ├── Active Coupons
    │   ├── Milestone Progress
    │   └── Referral Program (V3 new)
    │
    └── TAB 5: Profile (User Dashboard)
        ├── Edit Profile
        ├── Genre Preferences
        ├── Notification Settings
        ├── Booking Activity Charts
        ├── Taste Profile (Radar)
        ├── Influencer Hub (if role = influencer)
        │   ├── Submit Ad Request
        │   └── My Ad Requests
        ├── Wishlist
        └── Settings
```

---

## 🔧 Phase 1 — Bottom Navigation Bar Rebuild

**File**: `lib/core/navigation/main_shell.dart`

Replace the existing bottom nav with `AnimatedBottomNavigationBar`.

### 5-Tab Configuration

```dart
tabs: [
  BottomNavItem(icon: Icons.home_rounded,         label: "Home"),
  BottomNavItem(icon: Icons.explore_rounded,      label: "Explore"),
  BottomNavItem(icon: Icons.confirmation_number_rounded, label: "Bookings"),
  BottomNavItem(icon: Icons.local_offer_rounded,  label: "Offers"),
  BottomNavItem(icon: Icons.person_rounded,       label: "Profile"),
]
```

### FAB Notch
Center FAB = "Quick Book" button (yellow circle, ticket icon).  
Tap → shows a bottom sheet with 3 quick options:
```
🎬  Book a Movie
🎪  Book an Event
📢  Submit Ad Request  (shown only if role = influencer/user)
```
Each option navigates to the appropriate flow.

### Active Tab Indicator
Active icon: yellow fill + label visible.  
Inactive: grey icon, no label.  
Switching tabs: `FadeScaleTransition` (200ms).  
Tab switch: `HapticFeedback.selectionClick()`.

### Notification Badge
Profile tab icon shows a badge (using `badges` package) with unread notification count.  
Count read from `/users/{uid}/unreadNotifications` in RTDB.  
Real-time stream — badge updates live.

---

## 🏠 Phase 2 — Home Tab (Complete Rebuild + BookMyShow Parity)

**File**: `lib/features/home/screens/home_screen.dart`

This is the primary discovery screen. Must match BookMyShow in feature completeness.

### 2.1 Top Bar
```
┌─────────────────────────────────────────────────┐
│ 📍 Hyderabad ▾        [Search Bar]   🔔  👤   │
└─────────────────────────────────────────────────┘
```

**City Selector** (📍 Hyderabad ▾):
- Tap → city picker bottom sheet
- Sheet shows: "Detect Location" (uses geolocator), then list of major cities
- Selecting a city: saves to `SharedPreferences` + `/users/{uid}/city` in RTDB
- All content filters by selected city

**Search Bar** (inline, not icon):
- Tapping expands to full-screen search (Hero animation)
- See Phase 3 for full search implementation

**Notification Bell** 🔔:
- Badge with unread count (real-time RTDB stream)
- Tap → Notifications screen (scrollable list of all past notifications)

**Avatar** 👤:
- User's avatar (CachedNetworkImage)
- Tap → Profile tab (Tab 5)

### 2.2 Promo Banner Carousel
Top of content area. Auto-scrolling `PageView` (4s interval).  
Each banner: Cloudinary image, 25px radius, gradient overlay, optional "Book Now" CTA chip.  
Dot indicator below using `SmoothPageIndicator`.  
Banner data from `/banners/` in RTDB (admin-managed in V1).

### 2.3 Quick Category Pills
Horizontal scroll row below banner:
```
[🎬 Movies] [🎪 Events] [🎭 Plays] [🎵 Concerts] [🏟 Sports]
```
Each pill: yellow when active, white when inactive, 25px radius.  
Tapping filters the "Now Showing" section below.

### 2.4 Content Sections (All with Skeleton Loading)

**Recommended for You** (personalised, see V1 FR-U-32):
- 3 cards visible, horizontal scroll, `ShowSnapMovieCard` widget

**Now Showing** (filtered by active category pill + city):
- Horizontal scroll, `ShowSnapMovieCard` widget
- "See All" → Explore tab filtered to Movies > Now Showing

**Upcoming**:
- Same layout, "Releasing [date]" chip on each card

**Events Near You**:
- `ShowSnapEventCard` widget (different aspect ratio — wider)
- "See All" → Explore tab filtered to Events

**Trending This Week**:
- Top 5 list style (ranked #1–#5), not cards — each is a horizontal list item:
  - Rank number (large, bold, yellow), poster thumbnail, title + genre + rating

### 2.5 ShowSnapMovieCard Widget (Complete)

This widget is used everywhere. Build it once, perfectly.

```
┌─────────────────────┐
│  [POSTER IMAGE]     │  ← Hero tag: movie_${id}
│  ┌──────┐           │  ← "NEW" / "SOLD OUT" ribbon
│  │ U/A  │           │  ← Certificate badge
│  └──────┘           │
│  ████ Rating        │  ← Star + numeric rating
│─────────────────────│
│  Movie Title        │  ← Auto-size, max 2 lines
│  Action • Telugu    │  ← Genre • Language chips
│  From ₹150          │  ← Lowest available price
└─────────────────────┘
```

States:
- Default: white card, 25px radius, `ShowSnapShadow.card`
- Sold out: greyscale filter on poster + red "Houseful" badge overlay
- Coming soon: "RELEASING [date]" chip, no price, "Notify Me" instead of "Book"
- `TappableScale` wrapper (from V2)
- Hero tag for shared element transition

"Notify Me" (for upcoming movies):
- Tap → writes to `/users/{uid}/movieWatchlist/{movieId}: true`
- Icon toggles filled/unfilled with scale animation
- Cloud Function triggers FCM when that movie's `status` changes to `showing`

### 2.6 ShowSnapEventCard Widget (Complete)

Wider landscape card (aspect 16:9):
- Banner image full-width, gradient overlay
- Category icon (🎵🎭🏟) + category label
- Event name (bold), organizer
- Date + venue chip
- Ticket price range
- "Interested" count (from RTDB)

---

## 🔍 Phase 3 — Explore Tab (Full Search + Browse)

**File**: `lib/features/explore/screens/explore_screen.dart`

### 3.1 Search

Full-screen search experience activated from home bar.

**Search Input**:
- `flutter_typeahead` for autocomplete
- Suggestions: movies, events, theaters, cast names
- Each suggestion type has a different leading icon
- Recent searches stored in `SharedPreferences`, shown when input is empty

**Search Results Screen**:
- 3-tab result view: Movies | Events | Theaters
- Each tab: `GridView` (movies/events) or `ListView` (theaters)
- "No results" empty state with illustration

### 3.2 Movies Browse

Grid of `ShowSnapMovieCard` widgets (2-col).

**Filter Sheet** (triggered by filter icon):
Bottom sheet with these controls:
```
Genre:        [Multi-select chips: Action, Drama, Comedy, Thriller, Horror, Romance, Sci-Fi]
Language:     [Multi-select chips: Telugu, Hindi, English, Tamil, Malayalam]
Certificate:  [U] [UA] [A]
Format:       [2D] [3D] [IMAX] [4DX]
Price Range:  RangeSlider ₹50–₹1000
Date:         Date range picker
Sort by:      [Relevance] [Release Date] [Rating] [Price Low→High]
```
"Apply Filters" button: yellow, 25px radius.  
Active filter count shown as badge on filter icon.

### 3.3 Events Browse

Same grid layout as movies but with `ShowSnapEventCard`.  
Additional filter: Category (Music / Comedy / Sports / Theatre / Festivals).

### 3.4 Theaters Browse

List view. Each theater row:
- Theater name + city + rating
- Distance from user (using geolocator)
- Running shows count
- "View Shows" → theater detail screen

**Theater Detail Screen** (`lib/features/explore/screens/theater_detail_screen.dart`):
- Theater banner/logo
- Now showing at this theater: scrollable list of movies
- Shows grid: movie × show time matrix
- Theater info: address (with "Get Directions" → opens Maps), facilities, screens count

---

## 🎬 Phase 4 — Complete Movie Booking Flow (End-to-End)

Every step below must be a complete, working screen. No stubs.

### 4.1 Movie Detail Screen (Enhance V2)

**Trailer Section**:
Use `youtube_player_flutter`. Parse YouTube video ID from `movie.trailerUrl`.  
Show thumbnail with play button overlay → taps to play inline (or fullscreen on rotate).

**User Ratings Section**:
- Average rating (from `/movies/{id}/ratings/` aggregate)
- Distribution bar chart (5★ to 1★ counts)
- "Rate This Movie" button (visible only if user has a past booking for this movie):
  - Shows `RatingBar` (flutter_rating_bar), 5 stars, half-star precision
  - Submits to `/movies/{id}/ratings/{uid}` + triggers Cloud Function to recompute average

**Social Proof**:
- "X people booked in the last 24 hours" — read from RTDB aggregate

### 4.2 Show Selection Screen (Complete)

**Step 1 — Date Picker**:
Horizontal scroll of date chips (today + next 13 days = 14 days).  
Format: "Today", "Tomorrow", "Wed 14", etc.  
Unavailable dates (no shows): greyed out, not tappable.

**Step 2 — Theater + Show Grid**:
After date selected, show list of theaters showing this movie on that date.

Each theater section:
```
┌─────────────────────────────────────────────────┐
│  Prasads IMAX ★4.2  📍 2.3km  [Dolby] [IMAX]  │
├─────────────────────────────────────────────────┤
│  [9:30 AM]  [12:15 PM]  [3:30 PM]  [7:00 PM]  │
│    ✓ Avail    ✓ Avail    ⚠ Few left  ✗ Full    │
└─────────────────────────────────────────────────┘
```
Show time button colors (from V2). Tapping → Seat Selection for that show.

**Format Filter**:
`[All] [2D] [3D] [IMAX] [4DX]` pill row at top.  
Filters the theater list.

### 4.3 Seat Selection Screen (Enhance V2)

**Category Tabs** at top of seat map:
```
[Silver ₹150]  [Gold ₹250]  [Platinum ₹400]
```
Tapping a category tab scrolls the seat map to that section + highlights those seats.

**Seat Map**:
Already built in V2. Ensure:
- Seat tooltip on long-press: shows seatId + category + price
- Accessibility seats: wheelchair icon, priority messaging "Accessible seating"
- "Best Available" button: auto-selects the best N available seats (N = previous selection count or 2):
  - Algorithm: prefer centre rows, centre seats, within Gold category
  - Selected seats highlight with bounce animation
  - Button label: "Best Available (2 seats)"

**Multi-Selection Panel** (bottom, from V2):
Enhance: each selected seat shows as a removable chip:
```
[A5 Gold ₹250 ✕]  [A6 Gold ₹250 ✕]
```
Tapping ✕ deselects seat with reverse bounce animation.

### 4.4 Order Summary Screen (Complete)

Layout:
```
BOOKING SUMMARY
───────────────────────────────────────
Movie / Event Details Card
  Poster thumbnail | Title | Date/Time
  Theater | Screen | Format
───────────────────────────────────────
Seats Breakdown
  A5 (Gold) .................. ₹250
  A6 (Gold) .................. ₹250
  Subtotal ................... ₹500
───────────────────────────────────────
Coupon / Reward
  [Enter Coupon Code]  [Apply]
  → "SHOW20" applied ✓  -₹100
───────────────────────────────────────
Price Breakdown
  Subtotal .................. ₹500
  Discount .................. -₹100
  Convenience Fee ........... +₹20
  ─────────────────────────────────
  Total ..................... ₹420
───────────────────────────────────────
[  Confirm & Pay  ₹420  ]
```

**Coupon Flow** (fully interactive):
1. User types code → real-time validation on each keystroke (debounced 800ms)
2. Valid: green border + checkmark + discount applied with animated price update
3. Invalid: red border + shake + error message below field
4. Remove coupon: ✕ chip on applied coupon, reverts price with animation

**Cancellation Policy**:
Expandable section below the CTA:
- "Free cancellation up to 2 hours before show"
- Tap to expand: full policy text
- `AnimatedSize` expansion

**Time Remaining**:
Show countdown from seat lock TTL: "Seats held for 06:42"  
If < 2 min: pulsing red text

### 4.5 Payment Screen

Simple, focused screen:

```
Payment Options
───────────────
○  UPI  (GPay, PhonePe, Paytm)
○  Credit / Debit Card
○  Net Banking
○  ShowSnap Wallet   Balance: ₹0  [Add Money]
───────────────
Total: ₹420
[  Pay ₹420  ]
```

**Razorpay Integration** (complete, not stubbed):
```dart
// Initialize Razorpay with options
// amount: totalAmount * 100 (paise)
// currency: INR
// key: from env.dart
// name: "ShowSnap"
// description: "${movie.title} - ${seats} seats"
// prefill: { email: user.email, contact: user.phone }
// theme: { color: "#F5A800" }

// On success → confirmBooking() → navigate to E-Ticket
// On error → releaseSeats() → ShowSnapToast error → stay on screen
// On cancel → releaseSeats() → navigate back to Order Summary
```

### 4.6 E-Ticket Screen (Enhance V2)

Add:
- **Add to Calendar** button: creates a calendar event via `add_2_calendar` package (add to pubspec):
  ```dart
  Event(
    title: "${movie.title} @ ${theater.name}",
    startDate: showDateTime,
    endDate: showDateTime.add(Duration(minutes: movie.duration + 15)),
    location: theater.address,
  )
  ```
- **Track Journey** button: shows a `timeline_tile` widget:
  ```
  ✅ Booking Confirmed  — 2:30 PM
  ⏳ Show Time         — 7:00 PM  [3h 45m away]
  ○  Arrive at Theater — 6:45 PM  [reminder set]
  ○  Show Starts       — 7:00 PM
  ○  Show Ends         — 9:30 PM
  ```
- **QR Refresh**: if ticket status = "redeemed", show green "Redeemed ✓" overlay on QR with checkmark animation

---

## 🎪 Phase 5 — Complete Event Booking Flow

**File**: `lib/features/events/screens/event_detail_screen.dart`

### Event Detail

Layout similar to Movie Detail but with event-specific content:
- Banner image (full-width, 250px height, 25px bottom radius)
- Event name, organizer, date/time, venue
- "Interested" + "Share" buttons
- About section (expandable)
- Venue section: address + "Get Directions" button
- Artists / Performers: horizontal avatar scroll (like cast)

### Ticket Tiers

Replaces seat selection for events. Show tiers as a list:
```
┌─────────────────────────────────────────────────┐
│  🥇 VIP                          ₹2,500/person  │
│     Front section, meet & greet                  │
│     [   - 1 +   ]          234 left              │
├─────────────────────────────────────────────────┤
│  🥈 Premium                        ₹800/person  │
│     Numbered seating, centre area                │
│     [   - 2 +   ]         1,204 left             │
├─────────────────────────────────────────────────┤
│  🥉 General                        ₹350/person  │
│     Standing/open seating                        │
│     [   - 0 +   ]         2,890 left             │
└─────────────────────────────────────────────────┘
```

Quantity stepper `[-][count][+]`:
- "+" tap: increment with bounce animation + haptic light
- "-" tap: decrement with haptic
- Max 6 tickets per tier per transaction
- When count > 0: total updates at bottom with animated price change

Same Order Summary + Payment flow as movies.  
Event e-ticket: same design but shows tier name instead of seat IDs.

---

## 📋 Phase 6 — Advertisement Enquiry Form (Complete)

**Accessible from**: FAB quick-book sheet → "Submit Ad Request"  
**Also from**: Profile tab → Influencer Hub section  

**File**: `lib/features/influencer/screens/ad_request_form_screen.dart`

This is a multi-step form. 5 steps with a progress indicator.

### Progress Header
```
Step 1 of 5
●━━━━○━━━━○━━━━○━━━━○
Brand Info
```
Animated progress bar fills step-by-step (width: 20%→40%→60%→80%→100%).

### Step 1 — Brand & Campaign Info

```
Brand / Company Name *          [TextField]
Your Name *                     [TextField]
Contact Email *                 [TextField - email keyboard]
Contact Phone *                 [IntlPhoneField - with country code]
Campaign Title *                [TextField]
Campaign Description            [TextField - multiline, 4 lines]
Campaign Goal (select one)
  ○ Brand Awareness
  ○ Movie/Event Promotion
  ○ Product Launch
  ○ Seasonal Offer
```

All `*` fields: validate on "Next" tap. Show inline error below each invalid field.

### Step 2 — Target Selection

**Select Target Theaters** (multi-select):
List of all active theaters from RTDB.  
Each theater: checkbox + name + city.  
"Select All in [City]" shortcut button.  
Minimum 1 theater required.

**Select Screens** (conditional):
After theater selection, show screens per selected theater.  
"All Screens" option per theater + individual screen selection.

### Step 3 — Schedule & Budget

```
Campaign Start Date *    [Date Picker]
Campaign End Date *      [Date Picker]  (must be ≥ start date)

Preferred Display Slots  (multi-select chips)
  [Pre-show] [Interval] [Post-show] [All Day]

Estimated Daily Impressions: ~45,000 (computed from selected screens capacity)

Budget Range *
  ○ ₹10,000 – ₹50,000
  ○ ₹50,000 – ₹2,00,000
  ○ ₹2,00,000 – ₹5,00,000
  ○ ₹5,00,000+
  ○ Flexible / Open to Discussion
```

**Date validation**: end date must be > start date. Enforce with `DatePicker` min date.

### Step 4 — Creative Upload

```
Upload Ad Creative *

  ┌──────────────────────────────────┐
  │  [+ Add Image/Video]             │  ← file_picker, accepts jpg/png/mp4
  │  Max 3 files | Image: 5MB        │
  │  Video: 30 seconds, 50MB         │
  └──────────────────────────────────┘
```

Uploaded files shown as preview tiles:
- Images: thumbnail (CachedNetworkImage after Cloudinary upload)
- Videos: thumbnail with play icon + duration badge

Upload progress: `LinearProgressIndicator` per file (0→100%).  
Upload to Cloudinary `folder: "ad_creatives/{uid}"`.

"Additional Notes" text field (optional).

### Step 5 — Review & Submit

Full review summary — all data entered in steps 1–4 displayed in read-only card rows.  
Each section has an "Edit" link that jumps back to that step.

```
[ Brand Info           Edit ]
  Company: XYZ Corp
  Campaign: Summer Sale 2025

[ Targeting            Edit ]
  Theaters: Prasads IMAX, INOX Forum
  Screens: All screens

[ Schedule             Edit ]
  Jun 1 – Jun 30 • Pre-show + Interval
  Budget: ₹50k–₹2L

[ Creatives            Edit ]
  2 images uploaded

[ Accept Terms ]
  ☐ I confirm the submitted creatives comply with advertising standards
    and do not contain prohibited content.
```

Checkbox must be checked before "Submit" activates.

**Submit action**:
1. Button morphs to spinner
2. Write to `/adRequests/{uuid}` in RTDB (status: "pending")
3. Write to `/users/{uid}/adRequests/{uuid}`
4. Show success bottom sheet:
   - Confetti animation
   - "Request Submitted!" heading
   - "Our team will review your request within 24–48 hours"
   - Reference ID (bookingId style)
   - "Track Status" button → My Ad Requests screen

**Error handling**: Firebase write fail → toast error + keep form data intact.

---

## 👤 Phase 7 — Complete User Dashboard (Profile Tab)

**File**: `lib/features/user_dashboard/screens/user_dashboard_screen.dart`

The Profile tab IS the User Dashboard. Full `CustomScrollView`.

### 7.1 Profile Header Card (Yellow Gradient)

Already partially built in V2. Complete:

```
┌─────────────────────────────────────────────┐
│  [Avatar 80px]  Pavan Kumar           ✏️   │
│                 📍 Hyderabad                 │
│                 🎬 Gold Member              │
├──────────┬──────────────┬───────────────────┤
│ 12 Shows │  3 Rewards   │  2 Cities         │
└──────────┴──────────────┴───────────────────┘
```

**Edit Profile bottom sheet** (tap ✏️):
```
Name:      [TextField pre-filled]
City:      [TextField with flutter_typeahead — city autocomplete]
Phone:     [IntlPhoneField]
Bio:       [TextField, max 150 chars, char counter]
[Save Changes]  [Cancel]
```

On save: write to `/users/{uid}` in RTDB + `ShowSnapToast` success.

**Avatar change**: tap avatar → bottom sheet:
```
[📷 Take Photo]  [🖼 Choose from Gallery]  [🗑 Remove Photo]
```
Upload to Cloudinary `folder: "avatars/{uid}"`, update `/users/{uid}/avatarUrl`.

### 7.2 Stats Cards Grid (Animated Count-Up — from V2)

Already built in V2. Ensure data is **actually read from Firebase**:
- Total Spent: sum of `booking.totalAmount` where `status != 'cancelled'`
- Movies Watched: count of bookings where `status = 'redeemed'` + `type = 'movie'`
- Events Attended: count of bookings where `status = 'redeemed'` + `type = 'event'`
- Unique Genres: count distinct genre values across all booked movies

All computed via a `StreamProvider` that reads `/bookings/` filtered by uid.

### 7.3 Booking Activity Bar Chart (from V2 + data wired)

Ensure chart reads **real data** from RTDB.  
Group bookings by month using `intl` `DateFormat('MMM')`.  
Tap on a bar → bottom sheet showing that month's booking list.

### 7.4 Genre Taste Profile Radar (from V2 + data wired)

Read `/users/{uid}/affinityScores` from RTDB.  
If < 3 genres have data → show "Book more to unlock" empty state (Lottie popcorn animation).

### 7.5 Active Rewards & Milestone (Complete — data wired)

**Milestone Progress Card** (read from `/users/{uid}/totalUniqueMoviesBooked`):

```
┌─────────────────────────────────────────────────────────────┐
│  🎯  Book 3 more movies to earn a FREE ticket!              │
│                                                             │
│  [🎬][🎬][🎬][🎬][🎬][🎬][ ][ ][ ]                        │
│   ████████████████████████░░░░░░░░░░░░  6/9                 │
│                                                             │
│  Valid till: 30 Jun 2025        [View Eligible Movies]      │
└─────────────────────────────────────────────────────────────┘
```

Movie icons: tap each filled slot → navigates to that movie's detail.

**Active Coupon Cards** (read from `/coupons/` where user has used < maxUses and not expired):
```
┌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┐
│  SHOW20             Save ₹100          │
│  ─────────────────────────────────── ┆ │
│  Min order ₹300 • Valid till 30 Jun   │
│  [ Copy Code ]                        │
└╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘
```
Use `dotted_border` for the dashed card border.  
"Copy Code" → `Clipboard.setData` + ShowSnapToast "Code copied!".

### 7.6 My Bookings Summary (Linked to Tab 3)

Show last 3 bookings (cards, not full tab).  
"View All Bookings" link → jumps to Tab 3.

Each mini-card:
- Movie poster + title + date + status badge
- "View Ticket" if Confirmed/Redeemed
- "Rate Movie" if Redeemed + no rating given yet (post-show)

### 7.7 Influencer Hub Section

**Conditional**: show this section only if `user.role == 'influencer'` OR `user.role == 'user'` (all users can submit ad enquiries, but influencers get priority badge).

```
┌─────────────────────────────────────────────────┐
│  📢  Advertise with ShowSnap                    │
│  Reach thousands of moviegoers in your city     │
│                                                  │
│  [  Submit Ad Request  ]  [  My Requests  ]     │
└─────────────────────────────────────────────────┘
```

If `role = 'influencer'`:
- Show "Verified Influencer ✓" badge in green
- Show stats: "X ads approved", "~Y impressions delivered"

"Submit Ad Request" → Phase 6 multi-step form.

"My Requests" → list of all submitted requests:
```
Each request card:
- Campaign title + brand
- Target theaters
- Status badge: Pending (yellow) / Approved (green) / Rejected (red)
- Submitted date
- Tap to expand: full details + admin note (if rejected)
- If approved: show schedule dates + display locations
```

**Status change real-time**: attach a stream listener to `/users/{uid}/adRequests/`.  
When status changes to approved/rejected → show an in-app notification banner.

### 7.8 Wishlist Section

Already partially built in V2. Ensure:
- Heart icon on every `ShowSnapMovieCard` and `ShowSnapEventCard`
- Tap heart: toggle wishlist state in RTDB `/users/{uid}/wishlist/{itemId}: {type, addedAt}`
- Animated heart: outline → filled (red), scale bounce
- Dashboard section shows wishlist grid (2 col, same movie card)
- `flutter_slidable` on each wishlist item: swipe left → "Remove" action (red)
- "Notify me when on sale" toggle per wishlist item

### 7.9 Notification Preferences

Bottom sheet (accessible from Settings row):
```
All Notifications           [Toggle ON]

Booking Confirmations       [Toggle ON]  (non-toggleable)
Show Reminders              [Toggle ON]
New Shows for Wishlisted    [Toggle ON]
Offers & Promotions         [Toggle OFF]
Milestone Rewards           [Toggle ON]
Ad Request Updates          [Toggle ON]  (influencer only)
```
Write toggles to `/users/{uid}/notificationPrefs/` in RTDB.  
Cloud Functions check these prefs before sending FCM.

### 7.10 Settings Section

```
[Edit Profile]              →  Edit Profile bottom sheet
[Genre Preferences]         →  Multi-select genre chips + save
[Notification Settings]     →  Bottom sheet (7.9 above)
[City & Location]           →  City picker + location toggle
[Language Preference]       →  App language (Telugu / English)
[Privacy Policy]            →  WebView
[Terms of Service]          →  WebView
[Rate the App]              →  Opens app store review
[Sign Out]                  →  Confirmation dialog → Firebase signOut
[Delete Account]            →  Double-confirmation → mark account
                                for deletion → sign out
                                (actual deletion via Cloud Function)
```

---

## 📌 Phase 8 — My Bookings Tab (Tab 3, Complete)

**File**: `lib/features/bookings/screens/my_bookings_screen.dart`

### Layout: TabBar with 2 tabs

```
[  Upcoming (4)  ]  [  Past (8)  ]
```

### Upcoming Tab

Sorted by show time ascending.

Each booking card:
```
┌─────────────────────────────────────────────────┐
│ [Poster]  Movie Title                           │
│           📅 Wed, 14 Jun • 7:00 PM              │
│           🏛  Prasads IMAX, Screen 2            │
│           💺  A5, A6 (Gold)   ₹420 paid         │
│           ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│  [View Ticket]    [Add to Calendar]  [Cancel]   │
└─────────────────────────────────────────────────┘
```

**Cancel booking** (show only if > 2 hours before show time):
1. Tap "Cancel" → confirmation dialog with cancellation policy
2. Confirm → write `status: 'cancelled'` to RTDB + release seats (via Cloud Function)
3. Show `ShowSnapToast` success: "Booking cancelled. Refund initiated."
4. Card moves to Past tab immediately (optimistic UI update)

**Countdown timer** on upcoming bookings:
- If show is today: show "Starts in 3h 20m" with pulsing yellow dot
- If show is tomorrow: "Tomorrow, 7:00 PM"
- If < 30 min: "Starting soon!" in red with pulse

### Past Tab

Sorted by show time descending.

Each booking card (condensed):
- Same layout but no action buttons (except "View Ticket" + "Rate")
- "Rate Movie" button visible if:
  - `booking.status == 'redeemed'`
  - No rating in `/movies/{id}/ratings/{uid}`
  
**Rate Movie Flow**:
Bottom sheet with:
- Movie poster
- `RatingBar` (5 stars, half-star)
- Optional short review text field (max 200 chars)
- "Submit Rating" → write to `/movies/{id}/ratings/{uid}` + recompute average via Cloud Function
- Confetti burst on submit

**Empty States**:
- Upcoming empty: Lottie animation (empty seat), "No upcoming shows. Time to book something!" + "Browse Movies" CTA
- Past empty: "Your watched movies will appear here" + "Start your journey" CTA

---

## 🎟️ Phase 9 — Offers Tab (Tab 4, Complete)

**File**: `lib/features/offers/screens/offers_screen.dart`

### Layout: 3 sections

**Section 1 — Your Active Rewards**

Pull from `/users/{uid}/rewards/` — show unused rewards.
Each reward card:
- Reward type icon (🎟 free ticket / 💸 discount)
- Reward description
- Expiry countdown: "Expires in 5 days" (red if < 3 days)
- "Use This Reward" button → goes to movie selection with reward pre-applied

**Section 2 — Available Coupons**

Pull all active coupons from `/coupons/` where `isActive == true` and `expiryTs > now`.  
Dotted border cards (from V2 design).

**Section 3 — Referral Program**

New feature in V3:
```
┌─────────────────────────────────────────────────┐
│  🎁  Invite Friends, Earn Free Tickets          │
│                                                  │
│  Your Referral Code: PAVAN2025                  │
│  [  Share Code  ]   [  Copy  ]                  │
│                                                  │
│  Friends Referred: 3 of 5 needed for reward     │
│  ●●●○○   [3/5 friends joined]                   │
└─────────────────────────────────────────────────┘
```

Referral code = first 5 chars of `uid` + random suffix, stored at `/users/{uid}/referralCode`.  
Referral tracking stored at `/referrals/{code}/uses: [uid1, uid2, ...]`.  
When 5 referrals complete → Cloud Function creates a free ticket reward.  
Share code via `share_plus`.

---

## 🔍 Phase 10 — Feature Walkthrough (First-Time Users)

**File**: `lib/features/onboarding/feature_walkthrough.dart`

Use `showcaseview` package to highlight key UI elements on first login.

Showcase sequence (fires once, stored in `SharedPreferences`):
1. City selector: "Tap here to change your city"
2. Search bar: "Search any movie, event or theater"
3. FAB: "Quick-book from here anytime"
4. Offers tab: "Check your rewards and coupons here"
5. Profile tab: "Your complete booking history lives here"

Each tooltip: dark background, white text, yellow "Got it" button, 25px radius.

---

## 🔄 Phase 11 — Real-Time Cross-Screen Sync

These RTDB listeners must be active throughout the app lifecycle (attached at `main_shell.dart` level):

| RTDB Path | Action |
|---|---|
| `/users/{uid}/unreadNotifications` | Update badge on Profile tab |
| `/users/{uid}/rewards/` | Update Offers tab badge + trigger confetti if new reward |
| `/bookings/` (filtered by uid, status change) | Update My Bookings list in real-time |
| `/users/{uid}/adRequests/` (status change) | Show in-app banner for approved/rejected |

All listeners: attached in `init()`, disposed in `dispose()`.  
Use `StreamProvider` from Riverpod for all RTDB streams.

---

## ✅ Phase 12 — Complete Interactive Cross-Check

**Run through every item below. Mark each ✅ in `BUILD_LOG_V3.md` only when verified.**

### Navigation
- [ ] All 5 bottom nav tabs navigate to their screens
- [ ] FAB opens quick-book sheet with 3 options
- [ ] Every "See All" link opens the correct filtered screen
- [ ] No orphan screens (every screen reachable from navigation tree)
- [ ] Back navigation works correctly on all screens
- [ ] Hero transitions: Home → Movie Detail smooth (no tag conflict)
- [ ] GoRouter handles deep links for e-ticket sharing

### Home Tab
- [ ] City selector changes content to that city's movies/events
- [ ] Promo banner auto-scrolls every 4 seconds
- [ ] Category pill filters Now Showing section
- [ ] Recommended section shows personalised content (not same as Now Showing)
- [ ] "Notify Me" on upcoming movie: writes to wishlist + icon toggles
- [ ] All movie cards show skeleton shimmer on first load
- [ ] Pull-to-refresh works and re-fetches data

### Movie Booking Flow
- [ ] Movie Detail: trailer plays inline via YouTube player
- [ ] Movie Detail: "Rate" button only shows if user has past booking
- [ ] Date picker: unavailable dates are greyed out
- [ ] Show time buttons colour-coded correctly (green/yellow/grey/red)
- [ ] Seat map renders all seats from RTDB seatLayout array
- [ ] Seat tap runs RTDB transaction (not just local state change)
- [ ] Two simultaneous users cannot book the same seat (test with 2 simulators)
- [ ] TTL timer counts down, pulsing red at < 1 min
- [ ] "Best Available" selects centre seats intelligently
- [ ] Selected seat chips appear in bottom panel, each removable
- [ ] Coupon code validates against RTDB (not hardcoded)
- [ ] Valid coupon: animated price update
- [ ] Invalid coupon: shake + red border
- [ ] Razorpay opens with correct amount in paise
- [ ] Payment success: booking written to RTDB, seats marked booked
- [ ] Payment failure: seats released, toast error
- [ ] E-ticket: QR code generated with booking ID
- [ ] E-ticket: "Add to Calendar" creates calendar event
- [ ] E-ticket: "Share" opens system share sheet

### Event Booking Flow
- [ ] Event detail shows all fields (name, organizer, venue, date, artists)
- [ ] Tier selection quantity steppers work (+/-)
- [ ] Max 6 tickets per tier enforced
- [ ] Price updates in real-time as quantities change
- [ ] Same checkout + payment flow as movies
- [ ] Event e-ticket shows tier name correctly

### Ad Request Form
- [ ] Form validation: all required fields highlighted on invalid submit
- [ ] Step progress bar advances correctly
- [ ] Theater multi-select works
- [ ] Date picker enforces end > start
- [ ] File upload: image uploads to Cloudinary, thumbnail shown
- [ ] File upload: progress bar shown per file
- [ ] Video upload: supported + preview shown
- [ ] Review step: all data displayed accurately
- [ ] Terms checkbox required before submit
- [ ] Submit writes to RTDB `/adRequests/` with status "pending"
- [ ] Success bottom sheet shows with confetti + reference ID
- [ ] My Requests list shows submitted requests with correct status
- [ ] Status change (admin approves) reflects in real-time

### User Dashboard
- [ ] Profile header shows real user data (name, city, level)
- [ ] Avatar tap → camera/gallery/remove options
- [ ] Avatar upload → Cloudinary → RTDB update
- [ ] Edit profile saves correctly to RTDB
- [ ] Stats count-up animation fires when section scrolls into view
- [ ] Stats show real data from RTDB (not hardcoded)
- [ ] Bar chart shows real booking-per-month data
- [ ] Bar chart: tap bar → shows that month's bookings
- [ ] Radar chart shows real genre affinity data
- [ ] Radar chart empty state if < 3 genres
- [ ] Milestone progress reads from `totalUniqueMoviesBooked` in RTDB
- [ ] Milestone movie slots: tapping filled slot → movie detail
- [ ] Coupon copy button copies code + shows toast
- [ ] Wishlist grid loads saved items from RTDB
- [ ] Heart toggle on movie/event cards writes to RTDB
- [ ] Swipe to remove wishlist item (flutter_slidable)
- [ ] Influencer Hub section visible to all users
- [ ] "Submit Ad Request" → Phase 6 form
- [ ] "My Ad Requests" → list with real RTDB data
- [ ] Notification toggles write to RTDB
- [ ] Sign Out → confirmation → Firebase signOut → redirect to Login
- [ ] Delete Account → double confirmation → mark for deletion

### My Bookings Tab
- [ ] Upcoming + Past tabs switch correctly
- [ ] Countdown timer shows correctly for today's shows
- [ ] "Cancel" only shows if > 2 hours before show
- [ ] Cancel → confirmation → RTDB update → seats released
- [ ] "Rate Movie" only shows if status = redeemed + no rating given
- [ ] Rating submits to RTDB correctly
- [ ] Confetti on rating submit
- [ ] Both empty states show with CTAs

### Offers Tab
- [ ] Active rewards loaded from RTDB
- [ ] Coupons loaded from RTDB (filtered: active + not expired)
- [ ] Referral code generated and displayed
- [ ] "Share Code" opens system share sheet
- [ ] Referral progress (3/5) reads from `/referrals/` in RTDB

### General
- [ ] All 25px border radii intact (no regressions from V2)
- [ ] All shimmer skeletons show on loading states
- [ ] All buttons have loading state (morphing loader)
- [ ] All forms validate and show inline errors
- [ ] All destructive actions have confirmation dialogs
- [ ] All Firebase writes have error handling + toast
- [ ] No hardcoded user IDs or test data in production code
- [ ] `flutter analyze` → zero errors, zero warnings
- [ ] App runs without crash on Android emulator
- [ ] App runs without crash on iOS simulator
- [ ] Feature walkthrough fires on first login only
- [ ] Real-time listeners properly disposed on widget dispose
- [ ] No memory leaks from animation controllers (all disposed)

---

## 📝 Phase 13 — Final Documentation

### Update `README.md`
Add complete user journey flows as diagrams.

### Create `USER_FLOWS.md`
Document every user-facing flow:
```
Movie Booking: Home → Movie Detail → Date Selection → 
               Theater Selection → Show Time → 
               Seat Selection → Order Summary → 
               Payment → E-Ticket

Event Booking: Home → Event Detail → 
               Tier Selection → Order Summary → 
               Payment → E-Ticket

Ad Request:    FAB → Ad Request Form (5 steps) → 
               Review → Submit → My Requests

Reward Flow:   Book movies → Milestone tracker updates → 
               Threshold hit → Reward unlocked (confetti) → 
               Apply at checkout
```

### Create `CROSS_CHECK_V3.md`
Copy the checklist from Phase 12 with all items marked ✅ (do not mark until actually verified).

---

## 🏁 V3 Done When

Every item in the Phase 12 cross-check list is ticked ✅ in `CROSS_CHECK_V3.md`.  
`flutter analyze` → zero issues.  
App launches, a new user can: register → set preferences → book a movie → see e-ticket → view it in My Bookings → rate the movie → submit an ad request → track it in their dashboard.  
All in one session. No crashes. No dead ends.

---

*V3 Prompt — ShowSnap Full Functional Dashboard*  
*Final layer: BookMyShow parity + complete user journeys*  
*10X Technologies — Pavan + Venkat Malla*
