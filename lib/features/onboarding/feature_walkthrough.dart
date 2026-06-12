import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../core/config/theme.dart';

// ─── Walkthrough Keys ─────────────────────────────────────────────────────────
// Import this file and use these keys to wrap showcase targets anywhere in the tree.

final walkthroughCityKey = GlobalKey();
final walkthroughSearchKey = GlobalKey();
final walkthroughCategoryKey = GlobalKey();
final walkthroughFabKey = GlobalKey();
final walkthroughProfileKey = GlobalKey();

const _kPrefsKey = 'showsnap_walkthrough_v3_shown';

// ─── FeatureWalkthroughWrapper ────────────────────────────────────────────────
// Wraps the top-level shell in ShowCaseWidget so Showcase widgets throughout
// the tree can reference the context.

class FeatureWalkthroughWrapper extends StatefulWidget {
  final Widget child;
  const FeatureWalkthroughWrapper({super.key, required this.child});

  @override
  State<FeatureWalkthroughWrapper> createState() =>
      _FeatureWalkthroughWrapperState();

  // Call from any context that's inside this wrapper to start the walkthrough.
  static void startIfFirstLaunch(BuildContext context) {
    _FeatureWalkthroughWrapperState._startIfFirstLaunch(context);
  }
}

class _FeatureWalkthroughWrapperState
    extends State<FeatureWalkthroughWrapper> {
  static BuildContext? _showCaseContext;

  static Future<void> _startIfFirstLaunch(BuildContext ctx) async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool(_kPrefsKey) ?? false;
    if (shown) return;
    if (_showCaseContext == null) return;
    // Brief delay so the HomeScreen layout completes
    await Future.delayed(const Duration(milliseconds: 600));
    if (_showCaseContext == null) return;
    ShowCaseWidget.of(_showCaseContext!).startShowCase([
      walkthroughCityKey,
      walkthroughSearchKey,
      walkthroughCategoryKey,
      walkthroughFabKey,
      walkthroughProfileKey,
    ]);
    await prefs.setBool(_kPrefsKey, true);
  }

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      blurValue: 1.5,
      disableBarrierInteraction: false,
      onComplete: (index, key) {},
      onFinish: () {},
      builder: (ctx) {
        _showCaseContext = ctx;
        return widget.child;
      },
    );
  }
}

// ─── ShowcaseTarget helper ────────────────────────────────────────────────────
// Wraps any widget with a Showcase tooltip. Uses ShowSnap brand colors.

class ShowcaseTarget extends StatelessWidget {
  final GlobalKey showcaseKey;
  final String title;
  final String description;
  final Widget child;
  final ShapeBorder shape;

  const ShowcaseTarget({
    required this.showcaseKey,
    required this.title,
    required this.description,
    required this.child,
    this.shape = const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(ShowSnapRadius.md))),
  });

  @override
  Widget build(BuildContext context) {
    return Showcase(
      key: showcaseKey,
      title: title,
      description: description,
      titleTextStyle: const TextStyle(
        color: Colors.black87,
        fontWeight: FontWeight.w800,
        fontSize: 16,
      ),
      descTextStyle: const TextStyle(
        color: Colors.black54,
        fontSize: 13,
        height: 1.4,
      ),
      tooltipBackgroundColor: Colors.white,
      targetShapeBorder: shape,
      targetBorderRadius:
          const BorderRadius.all(Radius.circular(ShowSnapRadius.md)),
      overlayOpacity: 0.75,
      child: child,
    );
  }
}
