# ShowSnap V2 — Architecture & Design Decisions

## Animation System

**flutter_animate over AnimationController everywhere**
Using `flutter_animate`'s declarative `.animate()` DSL for entrance animations keeps widget code readable. `AnimationController` is reserved for stateful interactions (shake, bounce-on-select) where we need programmatic control.

**Reduced motion**
Every animation widget checks `MediaQuery.disableAnimations`. `TappableScale` skips scale+haptic when this flag is true. Page transitions fall back to a simple fade.

**Duration tokens**
All durations are centralised in `ShowSnapDuration`:
- `fast` (200ms) — micro-interactions (toggle, state change)
- `normal` (350ms) — element entrances
- `slow` (550ms) — complex reveals
- `xslow` (800ms) — splash/logo
- `page` (450ms) — route transitions

## Design Tokens

`ShowSnapRadius.md` (25px) is the primary corner radius applied to cards, buttons, and sheets.
`ShowSnapShadow.elevated` (warm yellow glow) is used only on floating/featured elements — not every card — to preserve hierarchy.

## Confetti

`ConfettiController` lives in the `StatefulWidget` that owns the screen lifecycle. It is disposed in `dispose()`. The burst fires 700ms after the ticket entrance animation completes so it coincides with the elastic overshoot landing.

## Hero Transitions

Movie poster `Hero` tags follow the pattern `movie_poster_<movieId>`. The tag is applied in both `MovieCard` (list) and `MovieDetailScreen` (detail). The `CachedNetworkImage` is the Hero child — not a wrapper — so the image frame persists during the flight.

## Password Strength Bar

Computed client-side only as UX feedback. The backend `Validators.password` still enforces the minimum requirement. The bar has 4 segments (length ≥ 8, uppercase, digit, special char). Colors: red → orange → yellow → green.

## In-App Notification Banner

`NotificationService.showInAppBanner` inserts an `OverlayEntry` above the current route. It auto-dismisses after 3 seconds and supports an `onTap` callback for navigation. The banner slides down from `y = -1.0` (350ms, easeOutCubic) and fades in over 200ms.

## Toast vs SnackBar

`ShowSnapToast` (overlay-based) is used for transient feedback. The legacy `context.showSnackbar` extension is kept for backwards compatibility but new code uses `ShowSnapToast.success/error/warning/info`.

## fl_chart vs Other Chart Libraries

`fl_chart` was chosen for the dashboard because it supports both `BarChart` and `RadarChart` with Flutter-native rendering (no WebView). The `RadarChart` genre spider requires ≥ 3 bookings to avoid a single-axis degenerate shape.

## Cloudinary Upload

The app uses an **unsigned upload preset** (`ml_default`). The API secret never leaves Cloud Functions. The `getCloudinarySignature` Cloud Function generates signed requests when needed for deletion/transformation operations.
