# ShowSnap V4 — Decision Log

## D001 — Skip Syncfusion packages
- **Decision**: Replaced `syncfusion_flutter_charts` and `syncfusion_flutter_datepicker` with `fl_chart` (already installed v0.69.0) and Flutter's built-in `showDatePicker`.
- **Reason**: Syncfusion requires a paid license and has version conflicts with other packages in the project. `fl_chart` provides equivalent LineChart, BarChart, and PieChart capabilities without licensing overhead.

## D002 — Callback-based drawer navigation
- **Decision**: `AdminDrawer` and `TMDrawer` accept `Function(String route) onNavigateTo` callback instead of using a BuildContext extension.
- **Reason**: Initial attempt to add a `StaffNavExt` extension on BuildContext inside `staff_theme.dart` caused circular dependency with GoRouter. Callback pattern cleanly decouples the theme/widget file from routing — each screen calls `context.push(route)` directly.

## D003 — Movie title / screen name lookup in dashboard
- **Decision**: Added `Map<String, String> movieTitles` and `Map<String, String> screenNames` to `_TmDashStats` model and populated them from separate DB calls in the provider.
- **Reason**: `ShowModel` only stores foreign keys (`movieId`, `screenId`), not denormalized strings. Rather than modifying the core model, the dashboard provider fetches movies and screens once and builds lookup maps passed into the timeline widget.

## D004 — `ScreenModel.isActive` doesn't exist
- **Decision**: Replaced `screen.isActive` with `!screen.isUnderMaintenance` throughout.
- **Reason**: `ScreenModel` uses `isUnderMaintenance: bool` (defaults false) as its status field, not a separate `isActive` field.

## D005 — TMColors palette does not include `info`
- **Decision**: Used `const Color(0xFF42A5F5)` directly for the "Active Screens" stat card accent in the TM dashboard.
- **Reason**: `TMColors` is a warm amber palette and intentionally excludes a generic info color. The hex value matches `AdminColors.info` for visual consistency.

## D006 — `ShowSnapRadius` lives in `theme.dart`, not `staff_theme.dart`
- **Decision**: Added `import 'theme.dart'` to all new staff screens that use `ShowSnapRadius`.
- **Reason**: `ShowSnapRadius` is defined in `core/config/theme.dart`. `staff_theme.dart` re-uses it internally (via its own import of `theme.dart`) but does not re-export it. Each consuming file must import `theme.dart` directly.

## D007 — `ScreenModel.name` for screen name
- **Decision**: Used `screen.name` (not `screen.screenName`) in tm_reports_screen and all TM screens.
- **Reason**: The `ScreenModel` field is named `name` per the model definition.

## D008 — Conservative package versions
- **Decision**: Used known-stable version pins (e.g., `data_table_2: ^2.5.14`) rather than `^latest`.
- **Reason**: `^latest` was specified in the overview but `pub.dev` resolution at install time can pull in versions with breaking changes. Pinned ranges ensure reproducible builds.
