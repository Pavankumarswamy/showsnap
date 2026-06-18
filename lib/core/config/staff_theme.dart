import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'router.dart';
import 'theme.dart';
import '../../features/auth/providers/auth_provider.dart';

// ─── Admin Palette — Dark Command Center ──────────────────────────────────────

class AdminColors {
  static const background = Color(0xFF09090B);
  static const surface = Color(0x6618181B);
  static const surfaceElevated = Color(0x8027272A);
  static const border = Color(0x22FFFFFF);

  static const primary = Color(0xFFF5A800);
  static const primaryGlow = Color(0x33F5A800);
  static const secondary = Color(0xFF43A047);
  static const secondaryGlow = Color(0x2243A047);

  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);

  static const textPrimary = Color(0xFFFAFAFA);
  static const textSecondary = Color(0xFFA1A1AA);
  static const textMuted = Color(0xFF52525B);
}

// ─── Theater Manager Palette — Warm Operational ───────────────────────────────

class TMColors {
  static const background = AdminColors.background;
  static const surface = AdminColors.surface;
  static const surfaceElevated = AdminColors.surfaceElevated;
  static const border = AdminColors.border;

  static const primary = AdminColors.primary;
  static const primaryGlow = AdminColors.primaryGlow;
  static const secondary = AdminColors.secondary;
  static const accent = AdminColors.primary;

  static const success = AdminColors.success;
  static const warning = AdminColors.warning;
  static const error = AdminColors.error;

  static const textPrimary = AdminColors.textPrimary;
  static const textSecondary = AdminColors.textSecondary;
  static const textMuted = AdminColors.textMuted;
}

// ─── Shared Staff Shadows ─────────────────────────────────────────────────────

class StaffShadow {
  static List<BoxShadow> adminCard(Color glowColor) => [
        BoxShadow(color: glowColor, blurRadius: 16, offset: const Offset(0, 4)),
        BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2)),
      ];

  static List<BoxShadow> get subtle => [
        BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4)),
      ];
}

// ─── Staff Glass Card ─────────────────────────────────────────────────────────

class StaffGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? glowColor;
  final double borderRadius;
  final Color? surfaceColor;

  const StaffGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.glowColor,
    this.borderRadius = ShowSnapRadius.md,
    this.surfaceColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: glowColor != null
            ? [BoxShadow(color: glowColor!, blurRadius: 24, offset: const Offset(0, 8))]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: surfaceColor ?? AdminColors.surface,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: AdminColors.border, width: 0.5),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ─── Staff Stat Card ─────────────────────────────────────────────────────────

class StaffStatCard extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final Color bgColor;
  final String? delta;
  final bool isPositive;

  const StaffStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.bgColor,
    this.delta,
    this.isPositive = true,
  });

  @override
  State<StaffStatCard> createState() => _StaffStatCardState();
}

class _StaffStatCardState extends State<StaffStatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _countAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _countAnim =
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutQuart);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StaffGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      glowColor: widget.accentColor.withOpacity(0.08),
      surfaceColor: widget.bgColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.accentColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, color: widget.accentColor, size: 20),
              ),
              const Spacer(),
              if (widget.delta != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (widget.isPositive
                            ? AdminColors.success
                            : AdminColors.error)
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(ShowSnapRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.isPositive
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 10,
                        color: widget.isPositive
                            ? AdminColors.success
                            : AdminColors.error,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        widget.delta!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: widget.isPositive
                              ? AdminColors.success
                              : AdminColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AdminColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            widget.label,
            style: const TextStyle(
                fontSize: 12, color: AdminColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Staff Section Header ─────────────────────────────────────────────────────

class StaffSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color textColor;

  const StaffSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.textColor = AdminColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const Spacer(),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel!,
              style: const TextStyle(
                  color: AdminColors.primary, fontSize: 13),
            ),
          ),
      ],
    );
  }
}

// ─── Staff Empty State ────────────────────────────────────────────────────────

class StaffEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final Color iconColor;

  const StaffEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.ctaLabel,
    this.onCta,
    this.iconColor = AdminColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: iconColor),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AdminColors.textSecondary, fontSize: 14),
            ),
            if (ctaLabel != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onCta,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ShowSnapRadius.md),
                  ),
                ),
                child: Text(ctaLabel!,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Staff Confirm Dialog ─────────────────────────────────────────────────────

class StaffConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;
  final bool isDangerous;

  const StaffConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.confirmColor = AdminColors.primary,
    this.isDangerous = false,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    bool isDangerous = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => StaffConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        confirmColor: isDangerous ? AdminColors.error : AdminColors.primary,
        isDangerous: isDangerous,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1C1C1F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        side: const BorderSide(color: AdminColors.border),
      ),
      title: Text(title,
          style: const TextStyle(
              color: AdminColors.textPrimary, fontWeight: FontWeight.bold)),
      content: Text(message,
          style: const TextStyle(color: AdminColors.textSecondary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel',
              style: TextStyle(color: AdminColors.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: isDangerous ? Colors.white : Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ShowSnapRadius.md),
            ),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

// ─── Staff Badge ──────────────────────────────────────────────────────────────

class StaffBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool dot;

  const StaffBadge({
    super.key,
    required this.label,
    required this.color,
    this.dot = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(ShowSnapRadius.pill),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ─── Staff Shimmer Card ───────────────────────────────────────────────────────

class StaffShimmerCard extends StatelessWidget {
  final double height;
  final Color baseColor;
  final Color highlightColor;

  const StaffShimmerCard({
    super.key,
    this.height = 100,
    this.baseColor = AdminColors.surface,
    this.highlightColor = AdminColors.surfaceElevated,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        ),
      ),
    );
  }
}

// ─── Staff Search Bar ─────────────────────────────────────────────────────────

class StaffSearchBar extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final Color bgColor;
  final Color borderColor;
  final Color textColor;

  const StaffSearchBar({
    super.key,
    required this.hint,
    required this.onChanged,
    this.bgColor = AdminColors.surface,
    this.borderColor = AdminColors.border,
    this.textColor = AdminColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        border: Border.all(color: borderColor),
      ),
      child: TextField(
        style: TextStyle(color: textColor, fontSize: 14),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AdminColors.textMuted, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: AdminColors.textMuted, size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

// ─── Admin Drawer ─────────────────────────────────────────────────────────────

class AdminDrawer extends ConsumerWidget {
  final String currentRoute;
  final Function(String route) onNavigateTo;

  const AdminDrawer({
    super.key,
    required this.currentRoute,
    required this.onNavigateTo,
  });

  static const _items = [
    _NavItem(Icons.dashboard_rounded, 'Dashboard', '/admin'),
    _NavItem(Icons.theaters_rounded, 'Theaters', '/admin/theaters'),
    _NavItem(Icons.people_rounded, 'Users', '/admin/users'),
    _NavItem(Icons.image_rounded, 'Banners', '/admin/banners'),
    _NavItem(Icons.confirmation_number_rounded, 'Tickets', '/admin/tickets'),
    _NavItem(Icons.local_offer_rounded, 'Offers', '/admin/offers'),
    _NavItem(Icons.campaign_rounded, 'Ad Requests', '/admin/ad-requests'),
    _NavItem(Icons.analytics_rounded, 'Analytics', '/admin/analytics'),
  ];

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await StaffConfirmDialog.show(
      context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out?',
      confirmLabel: 'Sign Out',
      isDangerous: true,
    );
    if (ok == true && context.mounted) {
      await ref.read(authNotifierProvider.notifier).signOut();
      if (context.mounted) context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      backgroundColor: AdminColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: AdminColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AdminColors.primaryGlow,
                      borderRadius:
                          BorderRadius.circular(ShowSnapRadius.sm),
                    ),
                    child: const Icon(Icons.admin_panel_settings_rounded,
                        color: AdminColors.primary, size: 28),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'ShowSnap Admin',
                    style: TextStyle(
                        color: AdminColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Command Center',
                    style: TextStyle(
                        color: AdminColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Nav items
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _items.length,
                itemBuilder: (_, i) {
                  final item = _items[i];
                  final isActive = currentRoute == item.route ||
                      (item.route != '/admin' &&
                          currentRoute.startsWith(item.route));
                  return _DrawerNavTile(
                    item: item,
                    isActive: isActive,
                    onTap: () {
                      final pushLayout = context.findAncestorStateOfType<PushDrawerLayoutState>();
                      if (pushLayout != null) {
                        pushLayout.closeDrawer();
                      } else {
                        Navigator.pop(context);
                      }
                      if (!isActive) onNavigateTo(item.route);
                    },
                  );
                },
              ),
            ),
            // Sign out
            const Divider(color: AdminColors.border, height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded,
                  color: AdminColors.error),
              title: const Text('Sign Out',
                  style: TextStyle(color: AdminColors.error)),
              onTap: () {
                final pushLayout = context.findAncestorStateOfType<PushDrawerLayoutState>();
                if (pushLayout != null) {
                  pushLayout.closeDrawer();
                } else {
                  Navigator.pop(context);
                }
                _signOut(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  const _NavItem(this.icon, this.label, this.route);
}

class _DrawerNavTile extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;
  final Color activeColor;
  final Color inactiveColor;
  final Color activeBgColor;

  const _DrawerNavTile({
    required this.item,
    required this.isActive,
    required this.onTap,
    this.activeColor = AdminColors.primary,
    this.inactiveColor = AdminColors.textSecondary,
    this.activeBgColor = AdminColors.primaryGlow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? activeBgColor : Colors.transparent,
        borderRadius: BorderRadius.circular(ShowSnapRadius.sm),
        border: isActive
            ? Border(left: BorderSide(color: activeColor, width: 3))
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Icon(
            item.icon,
            color: isActive ? activeColor : inactiveColor,
            size: 22,
          ),
          title: Text(
            item.label,
            style: TextStyle(
              color: isActive ? activeColor : inactiveColor,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
          onTap: onTap,
          dense: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ShowSnapRadius.sm),
          ),
        ),
      ),
    );
  }
}

// ─── TM Drawer ────────────────────────────────────────────────────────────────

class TMDrawer extends ConsumerWidget {
  final String currentRoute;
  final String theaterName;
  final Function(String route) onNavigateTo;

  const TMDrawer({
    super.key,
    required this.currentRoute,
    required this.onNavigateTo,
    this.theaterName = 'My Theater',
  });

  static const _items = [
    _NavItem(Icons.dashboard_rounded, 'Dashboard', '/tm'),
    _NavItem(Icons.theaters_rounded, 'Screens', '/tm/screens'),
    _NavItem(Icons.movie_rounded, 'Movies', '/tm/movies'),
    _NavItem(Icons.schedule_rounded, 'Shows', '/tm/shows'),
    _NavItem(Icons.qr_code_scanner_rounded, 'Ticket Scanner', '/tm/scanner'),
    _NavItem(Icons.bar_chart_rounded, 'Reports', '/tm/reports'),
  ];

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          side: const BorderSide(color: TMColors.border),
        ),
        title: const Text('Sign Out',
            style: TextStyle(
                color: TMColors.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: TMColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: TMColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TMColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ShowSnapRadius.md),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await ref.read(authNotifierProvider.notifier).signOut();
      if (context.mounted) context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      backgroundColor: const Color(0xFF09090B),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: TMColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: TMColors.primaryGlow,
                      borderRadius:
                          BorderRadius.circular(ShowSnapRadius.sm),
                    ),
                    child: const Icon(Icons.theaters_rounded,
                        color: TMColors.primary, size: 28),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    theaterName,
                    style: const TextStyle(
                        color: TMColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'Theater Manager',
                    style:
                        TextStyle(color: TMColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _items.length,
                itemBuilder: (_, i) {
                  final item = _items[i];
                  final isActive = currentRoute == item.route ||
                      (item.route != '/tm' &&
                          currentRoute.startsWith(item.route));
                  return _DrawerNavTile(
                    item: item,
                    isActive: isActive,
                    activeColor: TMColors.primary,
                    inactiveColor: TMColors.textSecondary,
                    activeBgColor: TMColors.primaryGlow,
                    onTap: () {
                      final pushLayout = context.findAncestorStateOfType<PushDrawerLayoutState>();
                      if (pushLayout != null) {
                        pushLayout.closeDrawer();
                      } else {
                        Navigator.pop(context);
                      }
                      if (!isActive) onNavigateTo(item.route);
                    },
                  );
                },
              ),
            ),
            const Divider(color: TMColors.border, height: 1),
            ListTile(
              leading:
                  const Icon(Icons.logout_rounded, color: TMColors.error),
              title: const Text('Sign Out',
                  style: TextStyle(color: TMColors.error)),
              onTap: () {
                final pushLayout = context.findAncestorStateOfType<PushDrawerLayoutState>();
                if (pushLayout != null) {
                  pushLayout.closeDrawer();
                } else {
                  Navigator.pop(context);
                }
                _signOut(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Push Drawer Layout ───────────────────────────────────────────────────────

class PushDrawerLayout extends StatefulWidget {
  final Widget drawer;
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Color? backgroundColor;

  const PushDrawerLayout({
    super.key,
    required this.drawer,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.backgroundColor,
  });

  @override
  State<PushDrawerLayout> createState() => PushDrawerLayoutState();
}

class PushDrawerLayoutState extends State<PushDrawerLayout> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void toggleDrawer() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void closeDrawer() {
    if (_isOpen) {
      setState(() {
        _isOpen = false;
        _controller.reverse();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    PreferredSizeWidget? effectiveAppBar = widget.appBar;
    if (widget.appBar is AppBar) {
      final ab = widget.appBar as AppBar;
      effectiveAppBar = AppBar(
        key: ab.key,
        leading: isDesktop
            ? null // Hide hamburger on desktop
            : IconButton(
                icon: AnimatedIcon(
                  icon: AnimatedIcons.menu_close,
                  progress: _controller,
                ),
                onPressed: toggleDrawer,
              ),
        automaticallyImplyLeading: false,
        title: ab.title,
        actions: ab.actions,
        flexibleSpace: ab.flexibleSpace,
        bottom: ab.bottom,
        elevation: ab.elevation,
        scrolledUnderElevation: ab.scrolledUnderElevation,
        shadowColor: ab.shadowColor,
        shape: ab.shape ?? const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        backgroundColor: ab.backgroundColor,
        foregroundColor: ab.foregroundColor,
        iconTheme: ab.iconTheme,
        actionsIconTheme: ab.actionsIconTheme,
        primary: ab.primary,
        centerTitle: ab.centerTitle,
        excludeHeaderSemantics: ab.excludeHeaderSemantics,
        titleSpacing: ab.titleSpacing,
        toolbarOpacity: ab.toolbarOpacity,
        bottomOpacity: ab.bottomOpacity,
        toolbarHeight: ab.toolbarHeight,
        leadingWidth: isDesktop ? 0 : ab.leadingWidth,
        toolbarTextStyle: ab.toolbarTextStyle,
        titleTextStyle: ab.titleTextStyle,
        systemOverlayStyle: ab.systemOverlayStyle,
      );
    }

    if (isDesktop) {
      // If the drawer was open via animation, close it without animation to reset state
      if (_isOpen) {
        _isOpen = false;
        _controller.value = 0;
      }
      return Scaffold(
        backgroundColor: widget.backgroundColor ?? AdminColors.background,
        appBar: effectiveAppBar,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 260,
              child: Material(
                color: AdminColors.background,
                child: widget.drawer,
              ),
            ),
            Container(width: 1, color: AdminColors.border),
            Expanded(
              child: widget.body,
            ),
          ],
        ),
        floatingActionButton: widget.floatingActionButton,
      );
    }

    return Scaffold(
      backgroundColor: widget.backgroundColor ?? AdminColors.background,
      body: Stack(
        children: [
          Container(
            color: widget.backgroundColor ?? AdminColors.background,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 260,
                child: widget.drawer,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..translate(_controller.value * 260)
                  ..scale(1.0 - (_controller.value * 0.08)),
                alignment: Alignment.centerLeft,
                child: ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: Stack(
                    children: [
                      Scaffold(
                        backgroundColor: widget.backgroundColor,
                        appBar: effectiveAppBar,
                        body: widget.body,
                        floatingActionButton: widget.floatingActionButton,
                      ),
                      if (_isOpen)
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: toggleDrawer,
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              color: Colors.transparent,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
