import 'package:animations/animations.dart';
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
import '../../features/bookings/screens/my_bookings_screen.dart';
import '../../features/offers/screens/offers_screen.dart';
import '../../features/user_dashboard/screens/user_dashboard_screen.dart';
import '../../features/admin/screens/admin_dashboard_screen.dart';
import '../../features/admin/screens/user_management_screen.dart';
import '../../features/admin/screens/ticket_audit_screen.dart';
import '../../features/admin/screens/offers_screen.dart' as admin;
import '../../features/admin/screens/ad_requests_screen.dart';
import '../../features/theater_manager/screens/tm_dashboard_screen.dart';
import '../../features/theater_manager/screens/screen_manager_screen.dart';
import '../../features/theater_manager/screens/seat_layout_editor_screen.dart';
import '../../features/theater_manager/screens/movie_manager_screen.dart';
import '../../features/theater_manager/screens/show_scheduler_screen.dart';
import '../../features/theater_manager/screens/ticket_scanner_screen.dart';
import '../../features/influencer/screens/ad_request_form_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/onboarding/welcome_screen.dart';
import '../navigation/main_shell.dart';
import '../services/auth_service.dart';
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
  static const String myBookings = '/my-bookings';
  static const String offers = '/offers';
  static const String movieDetail = '/movie/:movieId';
  static const String showSelection = '/show-selection/:movieId';
  static const String seatSelection = '/seat-selection/:showId';
  static const String eventDetail = '/event/:eventId';
  static const String orderSummary = '/order-summary';
  static const String ticket = '/ticket/:bookingId';
  static const String adminDashboard = '/admin';
  static const String userManagement = '/admin/users';
  static const String ticketAudit = '/admin/tickets';
  static const String adminOffers = '/admin/offers';
  static const String adRequests = '/admin/ad-requests';
  static const String tmDashboard = '/tm';
  static const String screenManager = '/tm/screens';
  static const String seatLayoutEditor = '/tm/seat-layout/:screenId';
  static const String movieManager = '/tm/movies';
  static const String showScheduler = '/tm/shows';
  static const String ticketScanner = '/tm/scanner';
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

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final loc = state.matchedLocation;
      final authRoutes = {
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.welcome,
        AppRoutes.splash,
      };

      if (!isLoggedIn && !authRoutes.contains(loc)) return AppRoutes.login;

      if (isLoggedIn) {
        final email = authState.valueOrNull?.email ?? '';
        final isAdmin = email == 'admin@gmail.com';

        // Admin always lands on admin dashboard, blocked from user shell
        if (isAdmin && !loc.startsWith('/admin') && !authRoutes.contains(loc)) {
          return AppRoutes.adminDashboard;
        }
        // Regular user redirected away from login/register
        if (!isAdmin &&
            (loc == AppRoutes.login || loc == AppRoutes.register)) {
          return AppRoutes.home;
        }
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
              pageBuilder: (c, s) => _fadePage(c, s, const ExploreScreen()),
            ),
          ]),
          // Tab 2 — My Bookings
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.myBookings,
              pageBuilder: (c, s) =>
                  _fadePage(c, s, const MyBookingsScreen()),
            ),
          ]),
          // Tab 3 — Offers
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.offers,
              pageBuilder: (c, s) =>
                  _fadePage(c, s, const UserOffersScreen()),
            ),
          ]),
          // Tab 4 — Profile / Dashboard
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.userDashboard,
              pageBuilder: (c, s) =>
                  _fadePage(c, s, const UserDashboardScreen()),
            ),
          ]),
        ],
      ),

      // ── Booking drill-down (horizontal) ───────────────────────────────────
      GoRoute(
        path: AppRoutes.movieDetail,
        pageBuilder: (c, s) => _horizontalPage(
            c, s, MovieDetailScreen(movieId: s.pathParameters['movieId']!)),
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

      // ── Influencer ────────────────────────────────────────────────────────
      GoRoute(
          path: AppRoutes.adRequestForm,
          pageBuilder: (c, s) =>
              _verticalPage(c, s, const AdRequestFormScreen())),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});
