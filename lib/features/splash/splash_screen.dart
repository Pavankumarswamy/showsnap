import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/theme.dart';
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
      context.go('/home');
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
          decoration: BoxDecoration(gradient: ShowSnapTheme.splashGradient),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: ShowSnapShadow.elevated,
                      ),
                      child: const Center(
                        child: Text(
                          'S',
                          style: TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            color: ShowSnapColors.primary,
                            height: 1,
                          ),
                        ),
                      ),
                    )
                        .animate(target: reduceMotion ? 0 : 1)
                        .scale(
                          begin: const Offset(0.4, 0.4),
                          end: const Offset(1, 1),
                          duration: const Duration(milliseconds: 800),
                          delay: const Duration(milliseconds: 200),
                          curve: Curves.elasticOut,
                        ),

                    const SizedBox(height: 24),

                    // App name
                    const Text(
                      'ShowSnap',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    )
                        .animate(target: reduceMotion ? 0 : 1)
                        .slideY(
                          begin: 0.5,
                          end: 0,
                          duration: const Duration(milliseconds: 500),
                          delay: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                        )
                        .fadeIn(
                          duration: const Duration(milliseconds: 500),
                          delay: const Duration(milliseconds: 600),
                        ),

                    const SizedBox(height: 8),

                    // Tagline
                    const Text(
                      'Book Your Moment',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white70,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w400,
                      ),
                    )
                        .animate(target: reduceMotion ? 0 : 1)
                        .fadeIn(
                          duration: const Duration(milliseconds: 400),
                          delay: const Duration(milliseconds: 900),
                        ),
                  ],
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
                          color: Colors.white24,
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
                            color: Colors.white,
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
