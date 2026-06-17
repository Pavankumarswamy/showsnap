import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/config/theme.dart';

class PremiumTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;

  const PremiumTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onFieldSubmitted,
  });

  @override
  State<PremiumTextField> createState() => _PremiumTextFieldState();
}

class _PremiumTextFieldState extends State<PremiumTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
      if (_isFocused) {
        HapticFeedback.selectionClick();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: ShowSnapDuration.fast,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(ShowSnapRadius.md),
              border: Border.all(
                color: _isFocused
                    ? ShowSnapColors.primary
                    : Colors.white.withOpacity(0.1),
                width: 1.5,
              ),
            ),
            child: TextFormField(
              controller: widget.controller,
              focusNode: _focusNode,
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              onFieldSubmitted: widget.onFieldSubmitted,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: false,
                labelText: widget.label,
                labelStyle: TextStyle(
                  color: _isFocused
                      ? ShowSnapColors.primary
                      : Colors.white.withOpacity(0.6),
                ),
                prefixIcon: Icon(
                  widget.prefixIcon,
                  color: _isFocused
                      ? ShowSnapColors.primary
                      : Colors.white.withOpacity(0.6),
                ),
                suffixIcon: widget.suffixIcon,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
              ),
              validator: (val) {
                final err = widget.validator?.call(val);
                setState(() => _errorText = err);
                return err;
              },
            ),
          ),
        ),
      ),
    );
  }
}

class PremiumAuthButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String text;
  final bool isLoading;

  const PremiumAuthButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.isLoading = false,
  });

  @override
  State<PremiumAuthButton> createState() => _PremiumAuthButtonState();
}

class _PremiumAuthButtonState extends State<PremiumAuthButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (widget.onPressed != null && !widget.isLoading) {
          _ctrl.forward();
        }
      },
      onTapUp: (_) {
        if (widget.onPressed != null && !widget.isLoading) {
          _ctrl.reverse();
          HapticFeedback.lightImpact();
          widget.onPressed!();
        }
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: ShowSnapDuration.normal,
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
                widget.isLoading ? 28 : ShowSnapRadius.md),
            gradient: LinearGradient(
              colors: [
                ShowSnapColors.primary,
                ShowSnapColors.primaryLight,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: ShowSnapColors.primary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: ShowSnapDuration.fast,
              child: widget.isLoading
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : Text(
                      widget.text,
                      key: const ValueKey('text'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class SocialAuthButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const SocialAuthButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(ShowSnapRadius.md),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Center(
              child: Icon(icon, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
    ).animate().scale(
        begin: const Offset(0.9, 0.9),
        end: const Offset(1, 1),
        curve: Curves.easeOutBack,
        duration: ShowSnapDuration.normal);
  }
}

// Shake animation widget (reused)
class ShakeWidget extends StatefulWidget {
  final Widget child;
  const ShakeWidget({super.key, required this.child});

  @override
  State<ShakeWidget> createState() => ShakeWidgetState();
}

class ShakeWidgetState extends State<ShakeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _anim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  void shake() {
    HapticFeedback.vibrate();
    _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) =>
          Transform.translate(offset: Offset(_anim.value, 0), child: child),
      child: widget.child,
    );
  }
}
