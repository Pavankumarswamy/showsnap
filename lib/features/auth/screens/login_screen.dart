import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../providers/auth_provider.dart';
import '../widgets/premium_auth_widgets.dart';
import '../screens/web_login_screen.dart';
import '../../../core/config/router.dart';
import '../../../core/config/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/extensions.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  String _completePhoneNumber = '';
  bool _otpSent = false;

  final _shakeKey = GlobalKey<ShakeWidgetState>();

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    if (!_formKey.currentState!.validate()) return;
    if (_completePhoneNumber.isEmpty) return;

    await ref.read(authNotifierProvider.notifier).sendOtp(_completePhoneNumber);
    if (!mounted) return;
    
    // Check if error occurred, if not set otpSent to true
    if (!ref.read(authNotifierProvider).hasError) {
      setState(() {
        _otpSent = true;
      });
      context.showSnackbar('OTP Sent to WhatsApp');
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpCtrl.text.isEmpty || _otpCtrl.text.length < 6) {
      context.showErrorSnackbar('Please enter a valid 6-digit OTP');
      return;
    }
    await ref.read(authNotifierProvider.notifier).verifyOtp(_completePhoneNumber, _otpCtrl.text.trim());
  }

  Future<void> _signInWithGoogle() async {
    await ref.read(authNotifierProvider.notifier).signInWithGoogle();
  }

  Future<void> _navigateByRole() async {
    final authService = ref.read(authServiceProvider);
    await authService.ensureAdminRole();
    final user = authService.currentUser;
    if (user == null) return;
    
    // Check if new user (no display name)
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
    // On web, show the web-optimised login UI.
    if (kIsWeb) return const WebLoginScreen();

    final authState = ref.watch(authNotifierProvider);

    ref.listen(authNotifierProvider, (prev, next) {
      next.whenOrNull(
        data: (_) {
          if (prev != null && prev.isLoading && _otpSent && _otpCtrl.text.isNotEmpty) {
             _navigateByRole();
          } else if (prev != null && prev.isLoading && !_otpSent) {
             _navigateByRole(); // This handles Google Sign In success since _otpSent is false
          }
        },
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
                                    if (!_otpSent) ...[
                                      IntlPhoneField(
                                        controller: _phoneCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'Phone Number',
                                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            borderSide: const BorderSide(color: ShowSnapColors.primary),
                                          ),
                                          fillColor: Colors.white.withOpacity(0.05),
                                          filled: true,
                                        ),
                                        style: const TextStyle(color: Colors.white),
                                        dropdownTextStyle: const TextStyle(color: Colors.white),
                                        dropdownIcon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                                        initialCountryCode: 'IN',
                                        onChanged: (phone) {
                                          _completePhoneNumber = phone.completeNumber;
                                        },
                                      ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1, end: 0),
                                      
                                      const SizedBox(height: 24),

                                      // Request OTP Button
                                      ShakeWidget(
                                        key: _shakeKey,
                                        child: PremiumAuthButton(
                                          text: 'Continue with Phone',
                                          isLoading: authState.isLoading,
                                          onPressed: _requestOtp,
                                        ),
                                      ).animate().fadeIn(delay: 500.ms).scale(begin: const Offset(0.9, 0.9)),
                                    ] else ...[
                                      PremiumTextField(
                                        controller: _otpCtrl,
                                        label: 'Enter 6-digit OTP',
                                        prefixIcon: Icons.message_outlined,
                                        keyboardType: TextInputType.number,
                                        textInputAction: TextInputAction.done,
                                        onFieldSubmitted: (_) => _verifyOtp(),
                                      ).animate().fadeIn().slideX(begin: 0.1, end: 0),
                                      
                                      const SizedBox(height: 24),

                                      // Verify OTP Button
                                      ShakeWidget(
                                        key: _shakeKey,
                                        child: PremiumAuthButton(
                                          text: 'Verify OTP',
                                          isLoading: authState.isLoading,
                                          onPressed: _verifyOtp,
                                        ),
                                      ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),

                                      const SizedBox(height: 16),
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            _otpSent = false;
                                            _otpCtrl.clear();
                                          });
                                        },
                                        child: Text(
                                          'Change Phone Number',
                                          style: TextStyle(color: Colors.white.withOpacity(0.6)),
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 32),
                                    Row(
                                      children: [
                                        Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          child: Text('OR', style: TextStyle(color: Colors.white.withOpacity(0.5))),
                                        ),
                                        Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
                                      ],
                                    ).animate().fadeIn(delay: 600.ms),
                                    const SizedBox(height: 32),

                                    // Google Sign In Button
                                    SizedBox(
                                      width: double.infinity,
                                      height: 56,
                                      child: ElevatedButton.icon(
                                        icon: Image.network(
                                          'https://techdocs.akamai.com/identity-cloud/img/social-login/identity-providers/iconfinder-new-google-favicon-682665.png',
                                          height: 24,
                                        ),
                                        label: const Text(
                                          'Continue with Google',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          elevation: 0,
                                        ),
                                        onPressed: authState.isLoading ? null : _signInWithGoogle,
                                      ),
                                    ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2, end: 0),

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
}
