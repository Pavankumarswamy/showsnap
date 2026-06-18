import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/router.dart';
import '../../core/config/theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/auth_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _loadingBarCtrl;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _loadingBarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    // Wait for initial animations (~1.4s delay before loading bar)
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    _loadingBarCtrl.forward();

    // Wait for loading bar to finish + fade-out
    await Future.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;

    await _navigate();
  }

  Future<void> _navigate() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenWelcome = prefs.getBool('hasSeenWelcome') ?? false;
    final user = ref.read(authStateProvider).valueOrNull;

    if (!mounted) return;

    if (user != null) {
      final authService = ref.read(authServiceProvider);

      // Patch admin DB record to role='admin' if not already set.
      await authService.ensureAdminRole();

      // 1. Email-based admin check (instant — no DB round-trip)
      if (user.email == 'admin@gmail.com') {
        context.go(AppRoutes.adminDashboard);
        return;
      }

      // 2. DB role check for theaterManager / regular user
      final role = await authService.getCurrentUserRole();
      if (!mounted) return;
      if (role == AppConstants.roleAdmin) {
        context.go(AppRoutes.adminDashboard);
      } else if (role == AppConstants.roleTheaterManager) {
        context.go(AppRoutes.tmDashboard);
      } else {
        context.go(AppRoutes.home);
      }
    } else if (!hasSeenWelcome) {
      context.go('/welcome');
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _loadingBarCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: Container(
          color: Colors.white,
          child: Stack(
            children: [
              Center(
                child: Image.asset(
                  'assets/images/show_snap_logo.png',
                  width: 250,
                  fit: BoxFit.contain,
                )
                .animate(target: reduceMotion ? 0 : 1)
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1, 1),
                  duration: const Duration(milliseconds: 800),
                  delay: const Duration(milliseconds: 200),
                  curve: Curves.elasticOut,
                )
                .fadeIn(
                  duration: const Duration(milliseconds: 500),
                  delay: const Duration(milliseconds: 200),
                ),
              ),

              // Bottom loading bar
              Positioned(
                bottom: 60,
                left: 40,
                right: 40,
                child: AnimatedBuilder(
                  animation: _loadingBarCtrl,
                  builder: (_, __) => Stack(
                    children: [
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: ShowSnapColors.grey300,
                          borderRadius:
                              BorderRadius.circular(ShowSnapRadius.pill),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: CurvedAnimation(
                          parent: _loadingBarCtrl,
                          curve: Curves.easeInOut,
                        ).value,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: ShowSnapColors.primary,
                            borderRadius:
                                BorderRadius.circular(ShowSnapRadius.pill),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
