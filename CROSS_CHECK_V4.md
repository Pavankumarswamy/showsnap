# ShowSnap V4 — Cross-Check Checklist

## Spec Requirements

| Requirement | Status | Notes |
|---|---|---|
| Never modify user-side features (`home/`, `movies/`, `events/`, `bookings/`, `offers/`, `user_dashboard/`, `auth/`, `onboarding/`, `splash/`) | ✅ | Zero changes to those directories |
| Work only in `admin/`, `theater_manager/`, shared design tokens | ✅ | All changes confined to these areas |
| 25px border radius everywhere (`ShowSnapRadius.md`) | ✅ | Used throughout all new/upgraded screens |
| All loading states: shimmer skeletons (not spinners) | ✅ | `StaffShimmerCard` in all list screens |
| All toasts: `ShowSnapToast` — never raw `ScaffoldMessenger` | ✅ | Replaced all `context.showSnackbar` calls |
| All destructive actions: `StaffConfirmDialog` before proceeding | ✅ | Delete banner, deactivate user, close movie, mark redeemed |
| Every list: empty state (illustration + message + CTA) | ✅ | `StaffEmptyState` in all list screens |
| `flutter analyze` — zero errors | ✅ | 0 compile errors confirmed |
| Log decisions in `DECISIONS_V4.md` | ✅ | 8 decisions logged |
| Log phase completion in `BUILD_LOG_V4.md` | ✅ | 10 phases logged |

## Screen Inventory

### Admin Screens
| Screen | Status | Theme | Drawer | Shimmer | EmptyState | StaffConfirm | ShowSnapToast |
|---|---|---|---|---|---|---|---|
| admin_dashboard_screen.dart | ✅ Overhauled | AdminColors | ✅ | ✅ | N/A | N/A | N/A |
| theaters_screen.dart | ✅ New | AdminColors | ✅ | ✅ | ✅ | ✅ | ✅ |
| analytics_screen.dart | ✅ New | AdminColors | ✅ | ✅ | N/A | N/A | N/A |
| user_management_screen.dart | ✅ Upgraded | AdminColors | ✅ | ✅ | ✅ | ✅ | ✅ |
| ticket_audit_screen.dart | ✅ Upgraded | AdminColors | ✅ | ✅ | ✅ | ✅ | ✅ |
| ad_requests_screen.dart | ✅ Upgraded | AdminColors | ✅ | ✅ | ✅ | N/A | ✅ |
| offers_screen.dart | ✅ Upgraded | AdminColors | ✅ | ✅ | ✅ | N/A | ✅ |
| banners_screen.dart | ✅ Upgraded | AdminColors | ✅ | ✅ | ✅ | ✅ | ✅ |

### Theater Manager Screens
| Screen | Status | Theme | Drawer | Shimmer | EmptyState | StaffConfirm | ShowSnapToast |
|---|---|---|---|---|---|---|---|
| tm_dashboard_screen.dart | ✅ Overhauled | TMColors | ✅ | ✅ | ✅ | N/A | N/A |
| tm_reports_screen.dart | ✅ New | TMColors | ✅ | ✅ | N/A | N/A | N/A |
| screen_manager_screen.dart | ✅ Upgraded | TMColors | ✅ | ✅ | ✅ | N/A | ✅ |
| movie_manager_screen.dart | ✅ Upgraded | TMColors | ✅ | ✅ | ✅ | ✅ | ✅ |
| show_scheduler_screen.dart | ✅ Upgraded | TMColors | ✅ | ✅ | ✅ | N/A | ✅ |
| ticket_scanner_screen.dart | ✅ Upgraded | TMColors | ✅ | N/A | N/A | N/A | N/A |

## Key Design Tokens Applied
- `AdminColors.background` = #0F1117 (all admin screens)
- `TMColors.background` = #1A1208 (all TM screens)
- `AdminColors.primary` / `TMColors.primary` = #F5A800 (amber accent)
- `ShowSnapRadius.md` = 25px (all cards, dialogs, buttons)
- `StaffShimmerCard` = shimmer base #1A1D27, highlight #222638 (admin)
- `StaffShimmerCard` = shimmer base #261B0C, highlight #332410 (TM)

## Packages Newly Used
- `percent_indicator` — screen layout completion bars in `screen_manager_screen.dart`; occupancy bars in `tm_reports_screen.dart`
- `timeline_tile` — show timeline in `tm_dashboard_screen.dart`
- `fl_chart` — all charts (revenue LineChart, ticket PieChart, analytics BarChart)
