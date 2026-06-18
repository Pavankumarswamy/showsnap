import 'package:animations/animations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/profile_setup_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/explore/screens/explore_screen.dart';
import '../../features/explore/screens/theater_detail_screen.dart';
import '../../features/movies/screens/movie_detail_screen.dart';
import '../../features/movies/screens/show_selection_screen.dart';
import '../../features/movies/screens/seat_selection_screen.dart';
import '../../features/events/screens/event_detail_screen.dart';
import '../../features/checkout/screens/order_summary_screen.dart';
import '../../features/checkout/screens/ticket_screen.dart';
import '../../features/events/screens/event_order_summary_screen.dart';
import '../../features/bookings/screens/my_bookings_screen.dart';
import '../../features/offers/screens/offers_screen.dart';
import '../../features/user_dashboard/screens/user_dashboard_screen.dart';
import '../../features/user_dashboard/screens/notifications_screen.dart';
import '../../features/admin/screens/admin_dashboard_screen.dart';
import '../../features/admin/screens/theaters_screen.dart';
import '../../features/admin/screens/user_management_screen.dart';
import '../../features/admin/screens/ticket_audit_screen.dart';
import '../../features/admin/screens/offers_screen.dart' as admin;
import '../../features/admin/screens/ad_requests_screen.dart';
import '../../features/admin/screens/add_theater_screen.dart';
import '../../features/admin/screens/banners_screen.dart';
import '../../features/admin/screens/analytics_screen.dart';
import '../../features/theater_manager/screens/tm_dashboard_screen.dart';
import '../../features/theater_manager/screens/screen_manager_screen.dart';
import '../../features/theater_manager/screens/seat_layout_editor_screen.dart';
import '../../features/theater_manager/screens/movie_manager_screen.dart';
import '../../features/theater_manager/screens/show_scheduler_screen.dart';
import '../../features/theater_manager/screens/ticket_scanner_screen.dart';
import '../../features/theater_manager/screens/tm_show_details_screen.dart';
import '../../features/theater_manager/screens/tm_reports_screen.dart';
import '../../features/influencer/screens/ad_request_form_screen.dart';
import '../../features/event_manager/screens/em_dashboard_screen.dart';
import '../../features/event_manager/screens/em_events_screen.dart';
import '../../features/event_manager/screens/add_event_screen.dart';
import '../../features/event_manager/screens/em_event_details_screen.dart';
import '../../features/event_manager/screens/event_ticket_scanner_screen.dart';
import '../../features/event_manager/screens/em_analytics_screen.dart';
import '../../features/event_manager/screens/em_coupons_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/onboarding/welcome_screen.dart';
import '../navigation/main_shell.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../constants/app_constants.dart';
import '../config/theme.dart';

class AppRoutes {
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String register = '/register';
  static const String profileSetup = '/profile-setup';
  static const String home = '/home';
  static const String explore = '/explore';
  static const String theaterDetail = '/theater/:theaterId';
  static const String userDashboard = '/dashboard';
  static const String notifications = '/notifications';
  static const String myBookings = '/my-bookings';
  static const String offers = '/offers';
  static const String movieDetail = '/movie/:movieId';
  static const String showSelection = '/show-selection/:movieId';
  static const String seatSelection = '/seat-selection/:showId';
  static const String eventDetail = '/event/:eventId';
  static const String eventSummary = '/event-summary';
  static const String orderSummary = '/order-summary';
  static const String ticket = '/ticket/:bookingId';
  static const String adminDashboard = '/admin';
  static const String userManagement = '/admin/users';
  static const String ticketAudit = '/admin/tickets';
  static const String adminOffers = '/admin/offers';
  static const String adRequests = '/admin/ad-requests';
  static const String addTheater = '/admin/add-theater';
  static const String editTheater = '/admin/edit-theater/:id';
  static const String adminBanners = '/admin/banners';
  static const String adminTheaters = '/admin/theaters';
  static const String adminAnalytics = '/admin/analytics';
  static const String tmDashboard = '/tm';
  static const String tmReports = '/tm/reports';
  static const String screenManager = '/tm/screens';
  static const String seatLayoutEditor = '/tm/seat-layout/:screenId';
  static const String movieManager = '/tm/movies';
  static const String showScheduler = '/tm/shows';
  static const String ticketScanner = '/tm/scanner';
  static const String tmShowDetails = '/tm/show-details/:id';
  static const String emDashboard = '/em';
  static const String emEvents = '/em/events';
  static const String addEvent = '/em/add-event';
  static const String editEvent = '/em/edit-event/:id';
  static const String emEventDetails = '/em/event-details/:id';
  static const String eventTicketScanner = '/em/scanner';
  static const String emAnalytics = '/em/analytics';
  static const String emCoupons = '/em/coupons';
  static const String adRequestForm = '/influencer/ad-request';
}

Page<T> _horizontalPage<T>(BuildContext context, GoRouterState state, Widget child) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: ShowSnapDuration.page,
    transitionsBuilder: (_, animation, secondaryAnimation, child) =>
        SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          transitionType: SharedAxisTransitionType.horizontal,
          child: child,
        ),
  );
}

Page<T> _verticalPage<T>(BuildContext context, GoRouterState state, Widget child) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: ShowSnapDuration.page,
    transitionsBuilder: (_, animation, secondaryAnimation, child) =>
        SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          transitionType: SharedAxisTransitionType.vertical,
          child: child,
        ),
  );
}

Page<T> _fadePage<T>(BuildContext context, GoRouterState state, Widget child) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: ShowSnapDuration.normal,
    transitionsBuilder: (_, animation, secondaryAnimation, child) =>
        FadeScaleTransition(animation: animation, child: child),
  );
}

// Notifies GoRouter to re-run redirect whenever auth or user-model changes.
// Creating this separately avoids recreating the entire GoRouter on each emit.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    ref.listen<AsyncValue<User?>>(authStateProvider, (_, __) => notifyListeners());
    ref.listen<AsyncValue<UserModel?>>(currentUserModelProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: notifier,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      const authRoutes = {
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.welcome,
        AppRoutes.splash,
      };

      final authState = ref.read(authStateProvider);
      
      if (authState.isLoading) {
        if (loc == AppRoutes.splash) return null;
        return AppRoutes.splash;
      }

      final isLoggedIn = authState.valueOrNull != null;

      if (!isLoggedIn) {
        if (!authRoutes.contains(loc)) return AppRoutes.login;
        return null;
      }

      final firebaseUser = authState.valueOrNull;
      final email = firebaseUser?.email ?? '';
      
      final userModelAsync = ref.read(currentUserModelProvider);

      if (userModelAsync.isLoading) {
        if (loc == AppRoutes.splash || authRoutes.contains(loc)) return null;
        return AppRoutes.splash;
      }

      final userModel = userModelAsync.valueOrNull;
      final role = userModel?.role ?? AppConstants.roleUser;

      final isAdminByEmail = email == 'admin@gmail.com';
      final isAdmin = isAdminByEmail || role == AppConstants.roleAdmin;
      final isTM = !isAdmin && role == AppConstants.roleTheaterManager;
      final isEM = !isAdmin && !isTM && role == AppConstants.roleEventManager;

      final onAuthRoute = authRoutes.contains(loc);

      if (isAdmin && (loc == '/' || onAuthRoute)) {
        return AppRoutes.adminDashboard;
      }
      if (isTM && (loc == '/' || onAuthRoute)) {
        return AppRoutes.tmDashboard;
      }
      if (isEM && (loc == '/' || onAuthRoute)) {
        return AppRoutes.emDashboard;
      }

      if (!isAdmin && !isTM && !isEM && (loc == '/' || onAuthRoute)) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      // ── Splash & Onboarding ────────────────────────────────────────────────
      GoRoute(
          path: AppRoutes.splash,
          pageBuilder: (c, s) => _fadePage(c, s, const SplashScreen())),
      GoRoute(
          path: AppRoutes.welcome,
          pageBuilder: (c, s) => _fadePage(c, s, const WelcomeScreen())),

      // ── Auth ──────────────────────────────────────────────────────────────
      GoRoute(
          path: AppRoutes.login,
          pageBuilder: (c, s) => _fadePage(c, s, const LoginScreen())),
      GoRoute(
          path: AppRoutes.register,
          pageBuilder: (c, s) => _fadePage(c, s, const RegisterScreen())),
      GoRoute(
          path: AppRoutes.profileSetup,
          pageBuilder: (c, s) => _fadePage(c, s, const ProfileSetupScreen())),

      // ── 5-Tab Shell ───────────────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            MainShell(navigationShell: shell),
        branches: [
          // Tab 0 — Home
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.home,
              pageBuilder: (c, s) => _fadePage(c, s, const HomeScreen()),
            ),
          ]),
          // Tab 1 — Explore
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.explore,
              pageBuilder: (c, s) {
                final tab = s.uri.queryParameters['tab'];
                return _fadePage(c, s, ExploreScreen(initialTab: tab));
              },
            ),
          ]),
          // Tab 2 — Ad Request
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.adRequestForm,
              pageBuilder: (c, s) =>
                  _fadePage(c, s, const AdRequestFormScreen()),
            ),
          ]),
          // Tab 3 — Profile
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.userDashboard,
              pageBuilder: (c, s) =>
                  _fadePage(c, s, const UserDashboardScreen()),
            ),
          ]),
        ],
      ),

      // ── Bookings & Notifications Standalone ───────────────────────────────────────────────
      GoRoute(
          path: AppRoutes.notifications,
          pageBuilder: (c, s) =>
              _horizontalPage(c, s, const NotificationsScreen())),
      GoRoute(
          path: AppRoutes.myBookings,
          pageBuilder: (c, s) =>
              _horizontalPage(c, s, const MyBookingsScreen())),

      // ── Booking drill-down (horizontal) ───────────────────────────────────
      GoRoute(
        path: AppRoutes.movieDetail,
        pageBuilder: (c, s) {
          final movieId = s.pathParameters['movieId']!;
          final heroTag = s.extra as String?;
          return _horizontalPage(
            c,
            s,
            MovieDetailScreen(movieId: movieId, heroTag: heroTag),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.showSelection,
        pageBuilder: (c, s) => _horizontalPage(
            c,
            s,
            ShowSelectionScreen(movieId: s.pathParameters['movieId']!)),
      ),
      GoRoute(
        path: AppRoutes.seatSelection,
        pageBuilder: (c, s) => _horizontalPage(
            c,
            s,
            SeatSelectionScreen(showId: s.pathParameters['showId']!)),
      ),
      GoRoute(
        path: AppRoutes.eventDetail,
        pageBuilder: (c, s) => _horizontalPage(
            c,
            s,
            EventDetailScreen(eventId: s.pathParameters['eventId']!)),
      ),
      GoRoute(
        path: AppRoutes.theaterDetail,
        pageBuilder: (c, s) => _horizontalPage(
            c,
            s,
            TheaterDetailScreen(
                theaterId: s.pathParameters['theaterId']!)),
      ),

      // ── Checkout (vertical) ───────────────────────────────────────────────
      GoRoute(
          path: AppRoutes.eventSummary,
          pageBuilder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            return _fadePage(
              context,
              state,
              EventOrderSummaryScreen(
                eventId: extra['eventId'] as String? ?? '',
                tierQuantities: extra['tierQuantities'] as Map<int, int>? ?? {},
              ),
            );
          },
        ),
      GoRoute(
        path: AppRoutes.orderSummary,
        pageBuilder: (c, s) {
          final extra = s.extra as Map<String, dynamic>;
          return _verticalPage(
              c,
              s,
              OrderSummaryScreen(
                showId: extra['showId'] as String,
                selectedSeatIds: List<String>.from(extra['seatIds'] as List),
              ));
        },
      ),
      GoRoute(
        path: AppRoutes.ticket,
        pageBuilder: (c, s) => _verticalPage(
            c,
            s,
            TicketScreen(bookingId: s.pathParameters['bookingId']!)),
      ),

      // ── Admin ─────────────────────────────────────────────────────────────
      GoRoute(
          path: AppRoutes.adminDashboard,
          pageBuilder: (c, s) =>
              _horizontalPage(c, s, const AdminDashboardScreen())),
      GoRoute(
          path: AppRoutes.userManagement,
          pageBuilder: (c, s) =>
              _horizontalPage(c, s, const UserManagementScreen())),
      GoRoute(
          path: AppRoutes.ticketAudit,
          pageBuilder: (c, s) =>
              _horizontalPage(c, s, const TicketAuditScreen())),
      GoRoute(
          path: AppRoutes.adminOffers,
          pageBuilder: (c, s) =>
              _horizontalPage(c, s, const admin.OffersScreen())),
      GoRoute(
          path: AppRoutes.adRequests,
          pageBuilder: (c, s) =>
              _horizontalPage(c, s, const AdRequestsScreen())),
      GoRoute(
          path: AppRoutes.addTheater,
          pageBuilder: (c, s) {
            final extra = s.extra as Map<String, dynamic>?;
            return _verticalPage(
              c,
              s,
              AddTheaterScreen(
                fixedManagerId: extra?['fixedManagerId'] as String?,
                fixedManagerName: extra?['fixedManagerName'] as String?,
              ),
            );
          }),
      GoRoute(
          path: AppRoutes.editTheater,
          pageBuilder: (c, s) =>
              _verticalPage(c, s, AddTheaterScreen(theaterId: s.pathParameters['id']))),
      GoRoute(
          path: AppRoutes.adminBanners,
          pageBuilder: (c, s) =>
              _horizontalPage(c, s, const AdminBannersScreen())),
      GoRoute(
          path: AppRoutes.adminTheaters,
          pageBuilder: (c, s) =>
              _horizontalPage(c, s, const TheatersScreen())),
      GoRoute(
          path: AppRoutes.adminAnalytics,
          pageBuilder: (c, s) =>
              _horizontalPage(c, s, const AnalyticsScreen())),

      // ── Theater Manager ───────────────────────────────────────────────────
      GoRoute(
          path: AppRoutes.tmDashboard,
          pageBuilder: (c, s) =>
              _fadePage(c, s, const TmDashboardScreen())),
      GoRoute(
          path: AppRoutes.screenManager,
          pageBuilder: (c, s) =>
              _horizontalPage(c, s, const ScreenManagerScreen())),
      GoRoute(
        path: AppRoutes.seatLayoutEditor,
        pageBuilder: (c, s) => _horizontalPage(
            c,
            s,
            SeatLayoutEditorScreen(
                screenId: s.pathParameters['screenId']!)),
      ),
      GoRoute(
          path: AppRoutes.movieManager,
          pageBuilder: (c, s) =>
              _horizontalPage(c, s, const MovieManagerScreen())),
      GoRoute(
          path: AppRoutes.showScheduler,
          pageBuilder: (c, s) =>
              _horizontalPage(c, s, const ShowSchedulerScreen())),
      GoRoute(
          path: AppRoutes.ticketScanner,
          pageBuilder: (c, s) =>
              _horizontalPage(c, s, const TicketScannerScreen())),
      GoRoute(
        path: AppRoutes.tmShowDetails,
        pageBuilder: (c, s) => _horizontalPage(
            c,
            s,
            TmShowDetailsScreen(showId: s.pathParameters['id']!)),
      ),
      GoRoute(
          path: AppRoutes.tmReports,
          pageBuilder: (c, s) =>
              _horizontalPage(c, s, const TmReportsScreen())),

      // ── Event Manager ─────────────────────────────────────────────────────
      GoRoute(
          path: AppRoutes.emDashboard,
          pageBuilder: (c, s) =>
              _fadePage(c, s, const EmDashboardScreen())),
      GoRoute(
          path: AppRoutes.emEvents,
          pageBuilder: (c, s) =>
              _fadePage(c, s, const EmEventsScreen())),
      GoRoute(
          path: AppRoutes.addEvent,
          pageBuilder: (c, s) =>
              _verticalPage(c, s, const AddEventScreen())),
      GoRoute(
          path: AppRoutes.editEvent,
          pageBuilder: (c, s) =>
              _verticalPage(c, s, AddEventScreen(eventId: s.pathParameters['id']))),
      GoRoute(
          path: AppRoutes.emEventDetails,
          pageBuilder: (c, s) =>
              _horizontalPage(c, s, EmEventDetailsScreen(eventId: s.pathParameters['id']!))),
      GoRoute(
          path: AppRoutes.eventTicketScanner,
          pageBuilder: (c, s) =>
              _horizontalPage(c, s, const EventTicketScannerScreen())),
      GoRoute(
          path: AppRoutes.emAnalytics,
          pageBuilder: (c, s) =>
              _horizontalPage(c, s, const EmAnalyticsScreen())),
      GoRoute(
          path: AppRoutes.emCoupons,
          pageBuilder: (c, s) =>
              _horizontalPage(c, s, const EmCouponsScreen())),

    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});
