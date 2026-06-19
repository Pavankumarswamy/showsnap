import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../../../core/config/router.dart';
import '../../../core/config/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';

/// A web-optimised sign-in page.
/// Shown only when [kIsWeb] is true (guarded by [LoginScreen]).
class WebLoginScreen extends ConsumerStatefulWidget {
  const WebLoginScreen({super.key});

  @override
  ConsumerState<WebLoginScreen> createState() => _WebLoginScreenState();
}

class _WebLoginScreenState extends ConsumerState<WebLoginScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bgCtrl;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    await ref.read(authNotifierProvider.notifier).signInWithGoogleWeb();
  }

  Future<void> _navigateByRole() async {
    final authService = ref.read(authServiceProvider);
    await authService.ensureAdminRole();
    final user = authService.currentUser;
    if (user == null) return;

    if (user.displayName == null || user.displayName!.isEmpty) {
      if (mounted) context.go(AppRoutes.profileSetup);
      return;
    }

    final email = user.email ?? '';
    if (email == 'admin@gmail.com') {
      if (mounted) context.go(AppRoutes.adminDashboard);
      return;
    }

    final role = await authService.getCurrentUserRole();
    if (!mounted) return;
    if (role == AppConstants.roleAdmin) {
      context.go(AppRoutes.adminDashboard);
    } else if (role == AppConstants.roleTheaterManager) {
      context.go(AppRoutes.tmDashboard);
    } else if (role == AppConstants.roleEventManager) {
      context.go(AppRoutes.emDashboard);
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final size = MediaQuery.sizeOf(context);
    final isNarrow = size.width < 800;

    ref.listen(authNotifierProvider, (prev, next) {
      next.whenOrNull(
        data: (_) {
          if (prev != null && prev.isLoading) _navigateByRole();
        },
        error: (err, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err.toString().replaceAll('Exception: ', '')),
              backgroundColor: ShowSnapColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        },
      );
    });

    return Scaffold(
      backgroundColor: ShowSnapColors.background,
      body: isNarrow
          ? _NarrowLayout(
              authState: authState,
              hovering: _hovering,
              bgCtrl: _bgCtrl,
              onHover: (v) => setState(() => _hovering = v),
              onSignIn: _signInWithGoogle,
            )
          : _WideLayout(
              authState: authState,
              hovering: _hovering,
              bgCtrl: _bgCtrl,
              onHover: (v) => setState(() => _hovering = v),
              onSignIn: _signInWithGoogle,
            ),
    );
  }
}

// ─── Wide (≥800 px) — two-column layout ─────────────────────────────────────

class _WideLayout extends StatelessWidget {
  final AsyncValue<void> authState;
  final bool hovering;
  final AnimationController bgCtrl;
  final ValueChanged<bool> onHover;
  final VoidCallback onSignIn;

  const _WideLayout({
    required this.authState,
    required this.hovering,
    required this.bgCtrl,
    required this.onHover,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Left panel – branding ─────────────────────────────────────────
        Expanded(
          flex: 5,
          child: _BrandingPanel(bgCtrl: bgCtrl),
        ),

        // ── Right panel – sign-in card ────────────────────────────────────
        Expanded(
          flex: 4,
          child: Container(
            color: ShowSnapColors.background,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 48, vertical: 40),
                child: _SignInCard(
                  authState: authState,
                  hovering: hovering,
                  onHover: onHover,
                  onSignIn: onSignIn,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Narrow (<800 px) — single-column layout ─────────────────────────────────

class _NarrowLayout extends StatelessWidget {
  final AsyncValue<void> authState;
  final bool hovering;
  final AnimationController bgCtrl;
  final ValueChanged<bool> onHover;
  final VoidCallback onSignIn;

  const _NarrowLayout({
    required this.authState,
    required this.hovering,
    required this.bgCtrl,
    required this.onHover,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: 280,
            child: _BrandingPanel(bgCtrl: bgCtrl, compact: true),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: _SignInCard(
              authState: authState,
              hovering: hovering,
              onHover: onHover,
              onSignIn: onSignIn,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Branding panel ───────────────────────────────────────────────────────────

class _BrandingPanel extends StatelessWidget {
  final AnimationController bgCtrl;
  final bool compact;

  const _BrandingPanel({required this.bgCtrl, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: bgCtrl,
      builder: (_, child) {
        final t = bgCtrl.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(
                  math.cos(t * math.pi * 2) * 0.6,
                  math.sin(t * math.pi * 2) * 0.6),
              end: Alignment(
                  -math.cos(t * math.pi * 2) * 0.6,
                  -math.sin(t * math.pi * 2) * 0.6),
              colors: const [
                Color(0xFF1A1500),
                Color(0xFF2C2800),
                ShowSnapColors.secondary,
                Color(0xFF3D3910),
              ],
              stops: const [0.0, 0.3, 0.7, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // Decorative film-reel circles
              ..._buildDecorativeCircles(t),

              // Content
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 24 : 48,
                  vertical: compact ? 32 : 64,
                ),
                child: Column(
                  mainAxisAlignment: compact
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // App logo — white bg handled with white rounded container
                    Container(
                      width: compact ? 100 : 140,
                      height: compact ? 100 : 140,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 32,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(
                        'assets/images/Screenshot 2026-06-19 145131.png',
                        fit: BoxFit.contain,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 600.ms)
                        .scale(begin: const Offset(0.7, 0.7)),

                    SizedBox(height: compact ? 16 : 32),

                    if (!compact) ...[
                      // Headline
                      Text(
                        'Your seat is\nwaiting.',
                        style: const TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                          letterSpacing: -1,
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 200.ms, duration: 700.ms)
                          .slideY(begin: 0.3, end: 0),

                      const SizedBox(height: 20),

                      Text(
                        'Book movies, events & concerts\nin seconds. ShowSnap.',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withValues(alpha: 0.65),
                          height: 1.5,
                          fontWeight: FontWeight.w400,
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 400.ms, duration: 700.ms)
                          .slideY(begin: 0.3, end: 0),

                      const SizedBox(height: 48),

                      // Feature pills
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: const [
                          _FeaturePill(
                              icon: Icons.movie_filter_outlined,
                              label: 'Movies'),
                          _FeaturePill(
                              icon: Icons.event_outlined,
                              label: 'Events'),
                          _FeaturePill(
                              icon: Icons.confirmation_number_outlined,
                              label: 'Fast Checkout'),
                          _FeaturePill(
                              icon: Icons.star_outline_rounded,
                              label: 'Best Seats'),
                        ],
                      )
                          .animate()
                          .fadeIn(delay: 600.ms, duration: 700.ms)
                          .slideY(begin: 0.3, end: 0),
                    ] else ...[
                      const Text(
                        'ShowSnap',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Book movies, events & concerts',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildDecorativeCircles(double t) {
    return [
      Positioned(
        top: -80,
        right: -80,
        child: _AnimatedCircle(size: 320, opacity: 0.05, t: t),
      ),
      Positioned(
        bottom: 60,
        right: 40,
        child: _AnimatedCircle(size: 180, opacity: 0.07, t: t + 0.3),
      ),
      Positioned(
        top: 120,
        left: -40,
        child: _AnimatedCircle(size: 140, opacity: 0.06, t: t + 0.6),
      ),
    ];
  }
}

class _AnimatedCircle extends StatelessWidget {
  final double size;
  final double opacity;
  final double t;
  const _AnimatedCircle(
      {required this.size, required this.opacity, required this.t});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: t * math.pi,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: ShowSnapColors.primary.withValues(alpha: opacity),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: ShowSnapColors.primary, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sign-in card ─────────────────────────────────────────────────────────────

class _SignInCard extends StatelessWidget {
  final AsyncValue<void> authState;
  final bool hovering;
  final ValueChanged<bool> onHover;
  final VoidCallback onSignIn;

  const _SignInCard({
    required this.authState,
    required this.hovering,
    required this.onHover,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    final isLoading = authState.isLoading;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          const Text(
            'Sign in to ShowSnap',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          )
              .animate()
              .fadeIn(duration: 600.ms)
              .slideY(begin: 0.2, end: 0),

          const SizedBox(height: 8),

          Text(
            'Access your bookings, events and more.',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.55),
              fontWeight: FontWeight.w400,
            ),
          )
              .animate()
              .fadeIn(delay: 100.ms, duration: 600.ms),

          const SizedBox(height: 40),

          // Google Sign-In button
          _GoogleSignInButton(
            isLoading: isLoading,
            hovering: hovering,
            onHover: onHover,
            onPressed: isLoading ? null : onSignIn,
          )
              .animate()
              .fadeIn(delay: 200.ms, duration: 600.ms)
              .slideY(begin: 0.2, end: 0),

          const SizedBox(height: 32),

          // Divider
          Row(
            children: [
              Expanded(
                child: Divider(color: Colors.white.withValues(alpha: 0.1)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Secure sign-in',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: Divider(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ],
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 32),

          // Trust badges
          _TrustBadges().animate().fadeIn(delay: 400.ms),

          const SizedBox(height: 40),

          // Terms
          Center(
            child: Text(
              'By signing in you agree to our Terms of Service\nand Privacy Policy.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.3),
                height: 1.6,
              ),
            ),
          ).animate().fadeIn(delay: 500.ms),
        ],
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final bool hovering;
  final ValueChanged<bool> onHover;
  final VoidCallback? onPressed;

  const _GoogleSignInButton({
    required this.isLoading,
    required this.hovering,
    required this.onHover,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = hovering && onPressed != null;
    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      cursor: onPressed != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0.0, isActive ? -3.0 : 0.0, 0.0),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 60,
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withValues(alpha: 0.97)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: ShowSnapColors.primary.withValues(alpha: 0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF4285F4)),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _GoogleLogo(),
                        const SizedBox(width: 14),
                        const Text(
                          'Continue with Google',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F1F1F),
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/image.png',
      width: 24,
      height: 24,
    );
  }
}

class _TrustBadges extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Badge(icon: Icons.lock_outline_rounded, label: 'Encrypted'),
        const SizedBox(width: 24),
        _Badge(icon: Icons.verified_user_outlined, label: 'Verified'),
        const SizedBox(width: 24),
        _Badge(icon: Icons.flash_on_outlined, label: 'Instant'),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Badge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: ShowSnapColors.grey100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Icon(
            icon,
            color: ShowSnapColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.45),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
