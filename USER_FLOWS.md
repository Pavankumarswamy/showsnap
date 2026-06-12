# ShowSnap V3 — User Flow Documentation

## Flow 1: Movie Booking
```
HomeScreen
  → tap movie card
  → MovieDetailScreen (/movie/:id)
    → tap "Book Now"
    → SeatSelectionScreen (/movie/:id/seats/:showId)
      → select seats
      → tap "Proceed"
      → OrderSummaryScreen (/checkout/summary)
        → apply coupon (optional)
        → tap "Confirm & Pay"
        → TicketScreen (/ticket/:bookingId)
          → download / share / add to calendar
```

## Flow 2: Event Booking
```
HomeScreen → "Events Near You" section
  → tap event card
  → EventDetailScreen (/event/:id)
    → select ticket tiers & quantities
    → tap "Book N Tickets — ₹total"
    → (event booking confirmation — coming soon)
```

## Flow 3: Explore & Discover
```
HomeScreen → tap search bar
  → ExploreScreen (/explore)
    → Movies tab: filter by genre/language/certificate/sort
    → Events tab: grid of EventCards
    → Theaters tab: list → TheaterDetailScreen (/theater/:id)
      → shows now playing at theater
      → tap movie → MovieDetailScreen
```

## Flow 4: My Bookings
```
ProfileTab → "My Bookings" section (or bottom nav Bookings tab)
  → MyBookingsScreen (/my-bookings)
    → Upcoming tab: countdown, cancel button
    → Past tab: rate movie, view ticket
      → TicketScreen (/ticket/:bookingId)
```

## Flow 5: Ad Campaign (Influencer Hub)
```
UserDashboard → "Influencer Hub" section
  → "New Campaign" button
  → AdRequestFormScreen (/influencer/ad-request)
    → Step 1: Brand Info + phone
    → Step 2: Select theaters & screens
    → Step 3: Schedule dates + display slots + budget range
    → Step 4: Upload creative (file_picker → Cloudinary unsigned)
    → Step 5: Review summary + accept terms + submit
    → Success sheet (confetti) → back to Dashboard
```

## Flow 6: Offers & Rewards
```
Offers tab (/offers)
  → Rewards card (points balance)
  → Referral card: copy code, share via share_plus
  → Coupons: view active coupons, see expiry & min order
```

## Flow 7: Wishlist Management
```
UserDashboard → Wishlist section
  → swipe left on item → delete (Slidable with confirmation)
  → tap item → MovieDetailScreen or EventDetailScreen
```

## Flow 8: Notification Preferences
```
UserDashboard → bell icon in header
  → NotifPrefsSheet (bottom sheet)
    → toggles for: Booking Updates, New Movies, Offers, 
                   Event Reminders, Ad Request Updates
    → changes saved to RTDB /users/{uid}/notificationPrefs/
```

## Flow 9: First-Launch Feature Walkthrough
```
App launch (first time) → HomeScreen
  → ShowCaseWidget auto-starts after 600ms
  → Step 1: City selector — "Tap to change your city"
  → Step 2: Search bar — "Find movies, events, theaters"
  → Step 3: Category pills — "Filter by category"
  → Step 4: FAB — "Quick Book your next show"
  → Step 5: Profile nav — "Your bookings, wishlist & more"
  → Walkthrough marked complete in SharedPreferences
```

## Flow 10: Rate a Movie
```
MyBookingsScreen → Past tab
  → tap "Rate" on a past booking
  → RatingSheet (bottom sheet, 5-star × 2 for 10-point scale)
    → submit → RTDB /movies/{id}/ratings/{uid}
    → average recomputed → /movies/{id}/rating updated
```

## Navigation Guards
- Auth-protected routes redirect to `/auth/login` if `authStateProvider` is null
- Deep links into `/ticket/:id` and `/checkout/*` verify booking ownership
- Admin routes (`/admin/*`) check `user.isAdmin` in `currentUserModelProvider`
