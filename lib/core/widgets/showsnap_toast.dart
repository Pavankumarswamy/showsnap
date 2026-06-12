import 'package:flutter/material.dart';
import '../config/theme.dart';

enum ToastType { success, warning, error, info }

class ShowSnapToast {
  static OverlayEntry? _current;

  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.success,
    Duration duration = const Duration(seconds: 3),
  }) {
    _current?.remove();
    final overlay = Overlay.of(context);

    _current = OverlayEntry(
      builder: (_) => _ToastWidget(
        message: message,
        type: type,
        duration: duration,
        onDismiss: () {
          _current?.remove();
          _current = null;
        },
      ),
    );
    overlay.insert(_current!);
  }

  static void success(BuildContext context, String message) =>
      show(context, message: message, type: ToastType.success);

  static void error(BuildContext context, String message) =>
      show(context, message: message, type: ToastType.error);

  static void warning(BuildContext context, String message) =>
      show(context, message: message, type: ToastType.warning);

  static void info(BuildContext context, String message) =>
      show(context, message: message, type: ToastType.info);
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final Duration duration;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    _ctrl.forward();

    // Start progress animation matching duration
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {});
      }
    });

    Future.delayed(widget.duration, () {
      if (mounted) {
        _ctrl.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _accentColor {
    switch (widget.type) {
      case ToastType.success:
        return ShowSnapColors.secondary;
      case ToastType.warning:
        return ShowSnapColors.primary;
      case ToastType.error:
        return ShowSnapColors.error;
      case ToastType.info:
        return Colors.blue;
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case ToastType.success:
        return Icons.check_circle_rounded;
      case ToastType.warning:
        return Icons.warning_rounded;
      case ToastType.error:
        return Icons.cancel_rounded;
      case ToastType.info:
        return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.of(context).viewInsets.bottom +
          MediaQuery.of(context).padding.bottom +
          16,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ShowSnapRadius.md),
                boxShadow: ShowSnapShadow.card,
                border: Border(
                  left: BorderSide(color: _accentColor, width: 4),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(_icon, color: _accentColor, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.message,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              _ctrl.reverse().then((_) => widget.onDismiss()),
                          child: const Icon(Icons.close,
                              size: 16, color: ShowSnapColors.grey600),
                        ),
                      ],
                    ),
                  ),
                  // Progress bar
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 1.0, end: 0.0),
                    duration: widget.duration -
                        const Duration(milliseconds: 300),
                    builder: (_, v, __) => ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(ShowSnapRadius.md),
                        bottomRight: Radius.circular(ShowSnapRadius.md),
                      ),
                      child: LinearProgressIndicator(
                        value: v,
                        minHeight: 3,
                        backgroundColor: ShowSnapColors.grey100,
                        valueColor: AlwaysStoppedAnimation(_accentColor),
                      ),
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
