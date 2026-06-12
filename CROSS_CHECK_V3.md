# ShowSnap V3 — Cross-Check Checklist

## Navigation Reachability
| Screen | Route | Entry Points | Status |
|--------|-------|--------------|--------|
| HomeScreen | /home | Bottom nav tab 0 | ✅ |
| ExploreScreen | /explore | Bottom nav tab 1, Home search bar | ✅ |
| MyBookingsScreen | /my-bookings | Bottom nav tab 2 | ✅ |
| UserOffersScreen | /offers | Bottom nav tab 3 | ✅ |
| UserDashboard | /dashboard | Bottom nav tab 4 | ✅ |
| MovieDetailScreen | /movie/:id | Home MovieCard, ExploreScreen | ✅ |
| EventDetailScreen | /event/:id | Home EventCard, ExploreScreen | ✅ |
| TheaterDetailScreen | /theater/:id | ExploreScreen theaters tab | ✅ |
| SeatSelectionScreen | /movie/:id/seats/:showId | MovieDetailScreen | ✅ |
| OrderSummaryScreen | /checkout/summary | SeatSelectionScreen | ✅ |
| TicketScreen | /ticket/:bookingId | OrderSummaryScreen, MyBookings | ✅ |
| AdRequestFormScreen | /influencer/ad-request | UserDashboard Influencer Hub | ✅ |
| WelcomeScreen | /onboarding | First launch (auth guard) | ✅ |

## Form Validation
| Form | Required Fields | Validation | Status |
|------|----------------|------------|--------|
| AdRequestForm Step 1 | Brand name, Contact name, Phone, Campaign title | GlobalKey<FormState> + phone valid flag | ✅ |
| AdRequestForm Step 2 | At least 1 theater | Checked in _goNext() | ✅ |
| AdRequestForm Step 3 | Start date, End date, ≥1 display slot | Checked in _goNext() | ✅ |
| AdRequestForm Step 4 | Creative uploaded | Checked in _goNext() | ✅ |
| AdRequestForm Step 5 | Terms accepted | Checked in _submit() | ✅ |
| Login form | Email, Password | Flutter Form validation | ✅ |
| Booking seat selection | ≥1 seat | Disabled proceed until seats > 0 | ✅ |
| Coupon input | Valid code | Error animation (shake) | ✅ |

## Empty States
| Screen/Section | Empty State | Status |
|----------------|------------|--------|
| MyBookings Upcoming | "No upcoming bookings" + Browse Movies button | ✅ |
| MyBookings Past | "No past bookings yet" | ✅ |
| UserDashboard Wishlist | Shown when wishlist is empty | ✅ |
| ExploreScreen Movies | No movies found message | ✅ |
| ExploreScreen Events | No events found message | ✅ |
| ExploreScreen Theaters | No theaters available | ✅ |
| Home feed sections | Shimmer → handled by loading state | ✅ |

## Loading States (Shimmer)
| Screen | Shimmer | Status |
|--------|---------|--------|
| HomeScreen | Shimmer on movie/event card lists | ✅ |
| MyBookingsScreen | _LoadingShimmer widget | ✅ |
| ExploreScreen | _GridShimmer widget | ✅ |
| UserDashboard | Shimmer on wishlist/influencer sections | ✅ |
| TheaterDetailScreen | Linear progress while loading | ✅ |
| AdRequestForm Step 2 | LinearProgressIndicator while loading screens | ✅ |

## Destructive Action Confirmations
| Action | Confirmation | Status |
|--------|-------------|--------|
| Cancel booking | AlertDialog with Cancel / Yes, Cancel | ✅ |
| Remove from wishlist | Slidable delete action (swipe gesture) | ✅ |
| Seat deselection | Implicit (tap again) | ✅ |

## Firebase Error Handling (ShowSnapToast on error)
| Operation | Error Handling | Status |
|-----------|----------------|--------|
| submitAdRequest | try/catch + ShowSnapToast.error | ✅ |
| uploadCreative (Cloudinary) | try/catch + ShowSnapToast.error | ✅ |
| cancelBooking | try/catch + ShowSnapToast.error | ✅ |
| submitMovieRating | try/catch + ShowSnapToast.error | ✅ |
| addToWishlist | try/catch + ShowSnapToast.error | ✅ |
| removeFromWishlist | Slidable action with error handling | ✅ |

## Border Radius (ShowSnapRadius.md = 25.0)
- All cards: `BorderRadius.circular(ShowSnapRadius.md)` ✅
- All buttons: `BorderRadius.circular(ShowSnapRadius.md)` ✅
- Bottom sheets: `BorderRadius.vertical(top: Radius.circular(ShowSnapRadius.lg))` ✅
- Chips/pills: `BorderRadius.circular(ShowSnapRadius.pill)` ✅
- Search bar: `BorderRadius.circular(ShowSnapRadius.pill)` ✅

## Security Compliance
- ✅ No hardcoded API secrets in Dart source
- ✅ Cloudinary upload uses unsigned preset only
- ✅ Firebase Auth email/password (no plaintext password storage)
- ✅ RTDB rules enforced server-side (not in app code)
- ✅ `flutter_dotenv` / `const String.fromEnvironment()` for env vars

## DateTime Format
- All user-visible timestamps use `epochToDateTimeLabel` extension → "Wed, 14 Jun • 7:30 PM" ✅
- Date pickers use `DateFormat('dd MMM yyyy')` ✅

## Analyze Status
- Last run: `dart analyze --no-fatal-warnings` → 0 errors ✅
