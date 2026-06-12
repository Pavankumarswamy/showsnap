import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
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
      return ShowSnapColors.primary;
    case 4:
      return ShowSnapColors.secondary;
    default:
      return ShowSnapColors.grey300;
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
        error: (err, _) =>
            context.showErrorSnackbar(err.toString().replaceAll('Exception: ', '')),
      );
    });

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            // Gradient header
            Container(
              height: MediaQuery.of(context).size.height * 0.32,
              decoration: BoxDecoration(
                gradient: ShowSnapTheme.splashGradient,
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  // Header
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.22,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Join ShowSnap today',
                          style: TextStyle(
                              fontSize: 14, color: Colors.white70),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: ShowSnapDuration.normal)
                      .slideY(begin: -0.2, end: 0),

                  // Form card
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(ShowSnapRadius.lg),
                          topRight: Radius.circular(ShowSnapRadius.lg),
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding:
                            const EdgeInsets.fromLTRB(24, 32, 24, 24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _nameCtrl,
                                textCapitalization:
                                    TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Full Name',
                                  prefixIcon:
                                      Icon(Icons.person_outlined),
                                ),
                                validator: Validators.name,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon:
                                      Icon(Icons.email_outlined),
                                ),
                                validator: Validators.email,
                              ),
                              const SizedBox(height: 16),

                              // Password + strength bar
                              TextFormField(
                                controller: _passwordCtrl,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon:
                                      const Icon(Icons.lock_outlined),
                                  suffixIcon: AnimatedRotation(
                                    turns: _obscurePassword ? 0 : 0.5,
                                    duration: ShowSnapDuration.fast,
                                    child: IconButton(
                                      icon: Icon(_obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined),
                                      onPressed: () => setState(() =>
                                          _obscurePassword =
                                              !_obscurePassword),
                                    ),
                                  ),
                                ),
                                validator: Validators.password,
                              ),
                              const SizedBox(height: 8),
                              _PasswordStrengthBar(strength: _strength),
                              const SizedBox(height: 16),

                              // Confirm password + match indicator
                              TextFormField(
                                controller: _confirmCtrl,
                                obscureText: _obscureConfirm,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: 'Confirm Password',
                                  prefixIcon:
                                      const Icon(Icons.lock_outlined),
                                  suffixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Match indicator
                                      if (_confirmCtrl.text.isNotEmpty)
                                        AnimatedSwitcher(
                                          duration: ShowSnapDuration.fast,
                                          child: Icon(
                                            key: ValueKey(_passwordsMatch),
                                            _passwordsMatch
                                                ? Icons.check_circle_outline
                                                : Icons.cancel_outlined,
                                            color: _passwordsMatch
                                                ? ShowSnapColors.secondary
                                                : ShowSnapColors.error,
                                            size: 20,
                                          ),
                                        ),
                                      AnimatedRotation(
                                        turns: _obscureConfirm ? 0 : 0.5,
                                        duration: ShowSnapDuration.fast,
                                        child: IconButton(
                                          icon: Icon(_obscureConfirm
                                              ? Icons
                                                  .visibility_off_outlined
                                              : Icons
                                                  .visibility_outlined),
                                          onPressed: () => setState(() =>
                                              _obscureConfirm =
                                                  !_obscureConfirm),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                validator: (v) =>
                                    Validators.confirmPassword(
                                        v, _passwordCtrl.text),
                              ),
                              const SizedBox(height: 24),

                              // Submit button
                              SizedBox(
                                height: 52,
                                child: DecoratedBox(
                                  decoration:
                                      ShowSnapTheme.primaryButtonDecoration,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(
                                                ShowSnapRadius.md),
                                      ),
                                    ),
                                    onPressed:
                                        authState.isLoading ? null : _submit,
                                    child: AnimatedSwitcher(
                                      duration: ShowSnapDuration.fast,
                                      child: authState.isLoading
                                          ? const SizedBox(
                                              key: ValueKey('loading'),
                                              height: 22,
                                              width: 22,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.black,
                                              ),
                                            )
                                          : const Text(
                                              key: ValueKey('text'),
                                              'Create Account',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('Already have an account? '),
                                  TextButton(
                                    onPressed: () =>
                                        context.go(AppRoutes.login),
                                    child: const Text('Sign In'),
                                  ),
                                ],
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
                  color: filled ? color : ShowSnapColors.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        AnimatedDefaultTextStyle(
          duration: ShowSnapDuration.fast,
          style: TextStyle(fontSize: 11, color: color),
          child: Text(label),
        ),
      ],
    );
  }
}
