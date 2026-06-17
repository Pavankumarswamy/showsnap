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
import '../../../core/utils/validators.dart';
import '../../../core/utils/extensions.dart';

int _passwordStrength(String password) {
  if (password.isEmpty) return 0;
  int score = 0;
  if (password.length >= 8) score++;
  if (RegExp(r'[A-Z]').hasMatch(password)) score++;
  if (RegExp(r'[0-9]').hasMatch(password)) score++;
  if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) score++;
  return score;
}

Color _strengthColor(int strength) {
  switch (strength) {
    case 1:
      return Colors.red;
    case 2:
      return Colors.orange;
    case 3:
      return ShowSnapColors.primaryLight;
    case 4:
      return ShowSnapColors.primary;
    default:
      return Colors.white.withOpacity(0.1);
  }
}

String _strengthLabel(int strength) {
  switch (strength) {
    case 1:
      return 'Weak';
    case 2:
      return 'Fair';
    case 3:
      return 'Good';
    case 4:
      return 'Strong';
    default:
      return '';
  }
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  int _strength = 0;
  bool _passwordsMatch = false;

  final _shakeKey = GlobalKey<ShakeWidgetState>();

  @override
  void initState() {
    super.initState();
    _passwordCtrl.addListener(() {
      setState(() {
        _strength = _passwordStrength(_passwordCtrl.text);
        _passwordsMatch = _confirmCtrl.text.isNotEmpty &&
            _confirmCtrl.text == _passwordCtrl.text;
      });
    });
    _confirmCtrl.addListener(() {
      setState(() {
        _passwordsMatch = _confirmCtrl.text.isNotEmpty &&
            _confirmCtrl.text == _passwordCtrl.text;
      });
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    await ref.read(authNotifierProvider.notifier).signUp(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
          _nameCtrl.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    ref.listen(authNotifierProvider, (prev, next) {
      next.whenOrNull(
        data: (_) {
          if (prev?.isLoading ?? false) {
            context.go(AppRoutes.profileSetup);
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
                    flex: 3,
                    child: Center(
                      child: Image.network(
                        'https://i.ibb.co/ccD640W2/erasebg-transformed-10.png',
                        width: 320,
                        height: 320,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  // Bottom Sheet - Form
                  Expanded(
                    flex: 7,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: ShowSnapColors.surface,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(40),
                          topRight: Radius.circular(40),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 20,
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(40),
                          topRight: Radius.circular(40),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(32, 40, 32, 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Title
                              const Text(
                                'Create Account',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0),
                              
                              const SizedBox(height: 8),
                              
                              Text(
                                'Join ShowSnap today for exclusive perks',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.white.withOpacity(0.6),
                                ),
                              ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
                              
                              const SizedBox(height: 32),

                              // Form
                              Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    PremiumTextField(
                                      controller: _nameCtrl,
                                      label: 'Full Name',
                                      prefixIcon: Icons.person_outlined,
                                      textInputAction: TextInputAction.next,
                                      validator: Validators.name,
                                    ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1, end: 0),
                                    
                                    const SizedBox(height: 16),
                                    
                                    PremiumTextField(
                                      controller: _emailCtrl,
                                      label: 'Email Address',
                                      prefixIcon: Icons.email_outlined,
                                      keyboardType: TextInputType.emailAddress,
                                      validator: Validators.email,
                                    ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1, end: 0),
                                    
                                    const SizedBox(height: 16),
                                    
                                    PremiumTextField(
                                      controller: _passwordCtrl,
                                      label: 'Password',
                                      prefixIcon: Icons.lock_outline,
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.next,
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
                                        ],
                                      ),
                                    ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.1, end: 0),
                                    
                                    const SizedBox(height: 8),
                                    _PasswordStrengthBar(strength: _strength).animate().fadeIn(delay: 550.ms),
                                    const SizedBox(height: 16),
                                    
                                    PremiumTextField(
                                      controller: _confirmCtrl,
                                      label: 'Confirm Password',
                                      prefixIcon: Icons.lock_outline,
                                      obscureText: _obscureConfirm,
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => _submit(),
                                      validator: (v) => Validators.confirmPassword(v, _passwordCtrl.text),
                                      suffixIcon: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (_confirmCtrl.text.isNotEmpty)
                                            AnimatedSwitcher(
                                              duration: ShowSnapDuration.fast,
                                              child: Icon(
                                                key: ValueKey(_passwordsMatch),
                                                _passwordsMatch ? Icons.check_circle_outline : Icons.cancel_outlined,
                                                color: _passwordsMatch ? ShowSnapColors.primary : ShowSnapColors.error,
                                                size: 20,
                                              ),
                                            ),
                                          IconButton(
                                            icon: Icon(
                                              _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                              color: Colors.white.withOpacity(0.6),
                                            ),
                                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                          ),
                                        ],
                                      ),
                                    ).animate().fadeIn(delay: 600.ms).slideX(begin: 0.1, end: 0),
                                    
                                    const SizedBox(height: 32),

                                    // Submit Button
                                    ShakeWidget(
                                      key: _shakeKey,
                                      child: PremiumAuthButton(
                                        text: 'Create Account',
                                        isLoading: authState.isLoading,
                                        onPressed: _submit,
                                      ),
                                    ).animate().fadeIn(delay: 700.ms).scale(begin: const Offset(0.9, 0.9)),

                                    const SizedBox(height: 32),



                                    // Sign In Link
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text('Already have an account? ', style: TextStyle(color: Colors.white.withOpacity(0.6))),
                                        TextButton(
                                          onPressed: () => context.go(AppRoutes.login),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.zero,
                                            minimumSize: Size.zero,
                                          ),
                                          child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ).animate().fadeIn(delay: 1000.ms),

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

class _PasswordStrengthBar extends StatelessWidget {
  final int strength;
  const _PasswordStrengthBar({required this.strength});

  @override
  Widget build(BuildContext context) {
    if (strength == 0) return const SizedBox.shrink();
    final color = _strengthColor(strength);
    final label = _strengthLabel(strength);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (i) {
            final filled = i < strength;
            return Expanded(
              child: AnimatedContainer(
                duration: ShowSnapDuration.fast,
                height: 4,
                margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                decoration: BoxDecoration(
                  color: filled ? color : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        AnimatedDefaultTextStyle(
          duration: ShowSnapDuration.fast,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
          child: Text(label),
        ),
      ],
    );
  }
}
