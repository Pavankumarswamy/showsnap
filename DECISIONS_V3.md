# ShowSnap V3 — Architecture & Decision Log

## D-001: Navigation Architecture
**Decision**: `StatefulShellRoute.indexedStack` with `BottomAppBar` + `CircularNotchedRectangle`  
**Why**: Preserves stack state across 5 tabs without requiring `animated_bottom_navigation_bar` package. BottomAppBar natively supports the notch for the FAB.  
**Tradeoff**: No sliding animation between tab switches; `IndexedStack` keeps all branches mounted.

## D-002: Toast Widget Naming
**Decision**: Widget file is `showsnap_toast.dart` (single word, no underscore between show and snap)  
**Why**: Matches the class name `ShowSnapToast` exactly when lowercased. All 6 feature screens import this path.  
**Note**: `ShowSnapToast.show(context, message: '...', type: ToastType.error)` — message is named, type replaces isError.

## D-003: Riverpod Provider Placement
**Decision**: All `FutureProvider`/`StreamProvider` declared at file-level top, never inside `build()` methods  
**Why**: Riverpod throws if a provider is created inline inside a widget's build method. `_nowShowingMoviesProvider` in `theater_detail_screen.dart` was moved to top-level for this reason.

## D-004: ProviderScope for Bottom Sheet with ConsumerWidget
**Decision**: Use `UncontrolledProviderScope(container: ProviderScope.containerOf(context))` instead of deprecated `ProviderScope(parent: ...)`  
**Why**: `ProviderScope.parent` was deprecated in riverpod 3.x. The replacement is `UncontrolledProviderScope` which accepts a direct container reference.

## D-005: Cloudinary Upload Security
**Decision**: Flutter app uses unsigned upload preset only. API secret lives exclusively in Cloud Functions (`getCloudinarySignature`).  
**Why**: Hardcoding the Cloudinary API secret in Dart source would expose it in the compiled APK/IPA. The unsigned preset allows direct uploads for ad creatives without requiring a signed request from the app.

## D-006: AdRequestForm Wizard Structure
**Decision**: 5-step `PageView` with `NeverScrollableScrollPhysics`, programmatic navigation  
**Steps**: Brand Info → Theater Selection → Schedule & Budget → Creative Upload → Review & Submit  
**Why**: PageView keeps all step state in memory simultaneously; NeverScrollableScrollPhysics prevents accidental swipe navigation; validation gates prevent step advancement with missing required fields.

## D-007: Feature Walkthrough Architecture
**Decision**: `FeatureWalkthroughWrapper` wraps `MainShell` to provide `ShowCaseWidget` context; global keys in `feature_walkthrough.dart` imported by HomeScreen and MainShell  
**Why**: `ShowCaseWidget` must be an ancestor of all `Showcase` widgets. Placing it at `MainShell` level covers both the bottom nav and the home screen showcase targets in the same context.  
**Trigger**: `WidgetsBinding.addPostFrameCallback` in `HomeScreen.initState` + SharedPreferences flag `showsnap_walkthrough_v3_shown` prevents re-showing.

## D-008: Rewards Field Type
**Decision**: `user.rewards` is `Map<String, dynamic>` (reward items map); display uses `.length` as points proxy  
**Why**: The UserModel stores reward items as a map keyed by reward ID. The Offers screen `_RewardsCard` displays the count of reward items × 100 as a point total approximation until a dedicated `rewardPoints` field is added to UserModel.

## D-009: Booking Cancellation
**Decision**: Cancel is allowed only if show is > 2 hours away AND status == `BookingStatus.confirmed`  
**Why**: Standard entertainment industry cancellation policy; prevents last-minute abuse.  
**Implementation**: `_canCancel` getter in `_BookingCardState`; calls `db.updateBookingStatus(id, BookingStatus.cancelled)`.

## D-010: DateTime Display Format
**Decision**: All timestamps displayed as `"Wed, 14 Jun • 7:30 PM"` via `epochToDateTimeLabel` extension  
**Why**: Consistent, human-readable across all screens. Extension defined in `lib/core/utils/extensions.dart`.
