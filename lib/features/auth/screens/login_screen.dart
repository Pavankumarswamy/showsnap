import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../widgets/premium_auth_widgets.dart';
import '../../../core/config/router.dart';
import '../../../core/config/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/extensions.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  final _shakeKey = GlobalKey<ShakeWidgetState>();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authNotifierProvider.notifier).signIn(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
  }

  Future<void> _navigateByRole() async {
    final authService = ref.read(authServiceProvider);
    await authService.ensureAdminRole();
    final email = authService.currentUser?.email ?? '';
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

    ref.listen(authNotifierProvider, (prev, next) {
      next.whenOrNull(
        data: (_) => _navigateByRole(),
        error: (err, _) {
          _shakeKey.currentState?.shake();
          context.showErrorSnackbar(err.toString().replaceAll('Exception: ', ''));
        },
      );
    });

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [


            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Top Area - Large Logo
                  Expanded(
                    flex: 4,
                    child: Center(
                      child: Image.asset(
                        'assets/images/auth_logo.png',
                        width: 280,
                        height: 280,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  // Bottom Sheet - Form
                  Expanded(
                    flex: 6,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: ShowSnapColors.surface,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(40),
                          topRight: Radius.circular(40),
                        ),
                        // Box shadow removed
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(40),
                          topRight: Radius.circular(40),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Welcome Text
                              const Text(
                                'Welcome Back',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0),

                              
                              const SizedBox(height: 24),

                              // Form
                              Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    PremiumTextField(
                                      controller: _emailCtrl,
                                      label: 'Email Address',
                                      prefixIcon: Icons.email_outlined,
                                      keyboardType: TextInputType.emailAddress,
                                      validator: Validators.email,
                                    ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1, end: 0),
                                    
                                    const SizedBox(height: 8),
                                    
                                    PremiumTextField(
                                      controller: _passwordCtrl,
                                      label: 'Password',
                                      prefixIcon: Icons.lock_outline,
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => _submit(),
                                      validator: Validators.password,
                                      suffixIcon: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                              color: Colors.white.withOpacity(0.6),
                                            ),
                                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                          ),
                                          Icon(Icons.fingerprint, color: ShowSnapColors.primary.withOpacity(0.8)),
                                          const SizedBox(width: 12),
                                        ],
                                      ),
                                    ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.1, end: 0),
                                    
                                    const SizedBox(height: 16),
                                    
                                    // Remember Me & Forgot Password
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            HapticFeedback.selectionClick();
                                            setState(() => _rememberMe = !_rememberMe);
                                          },
                                          child: Row(
                                            children: [
                                              AnimatedContainer(
                                                duration: ShowSnapDuration.fast,
                                                width: 20,
                                                height: 20,
                                                decoration: BoxDecoration(
                                                  color: _rememberMe ? ShowSnapColors.primary : Colors.transparent,
                                                  border: Border.all(
                                                    color: _rememberMe ? ShowSnapColors.primary : Colors.white.withOpacity(0.4),
                                                    width: 1.5,
                                                  ),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: _rememberMe 
                                                    ? const Icon(Icons.check, size: 14, color: Colors.black)
                                                    : null,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Remember me',
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.8),
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () => _showForgotPasswordDialog(context),
                                          style: TextButton.styleFrom(
                                            foregroundColor: ShowSnapColors.primary,
                                            padding: EdgeInsets.zero,
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: const Text(
                                            'Forgot Password?',
                                            style: TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ).animate().fadeIn(delay: 600.ms),

                                    const SizedBox(height: 24),

                                    // Login Button
                                    ShakeWidget(
                                      key: _shakeKey,
                                      child: PremiumAuthButton(
                                        text: 'Sign In',
                                        isLoading: authState.isLoading,
                                        onPressed: _submit,
                                      ),
                                    ).animate().fadeIn(delay: 700.ms).scale(begin: const Offset(0.9, 0.9)),

                                    const SizedBox(height: 24),

                                    // Register Link
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text('New to ShowSnap? ', style: TextStyle(color: Colors.white.withOpacity(0.6))),
                                        TextButton(
                                          onPressed: () => context.go(AppRoutes.register),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.zero,
                                            minimumSize: Size.zero,
                                          ),
                                          child: const Text('Sign Up', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ).animate().fadeIn(delay: 1100.ms),

                                    // Extra padding for bottom safe area
                                    SizedBox(height: MediaQuery.of(context).padding.bottom),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ShowSnapColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Reset Password', style: TextStyle(color: Colors.white)),
        content: PremiumTextField(
          controller: emailCtrl,
          label: 'Email',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.6))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ShowSnapColors.primary,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              if (emailCtrl.text.isNotEmpty) {
                await ref.read(authNotifierProvider.notifier).sendPasswordReset(emailCtrl.text.trim());
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  context.showSnackbar('Reset email sent!');
                }
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}
