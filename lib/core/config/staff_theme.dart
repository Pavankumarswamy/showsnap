import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'theme.dart';

// ─── Admin Palette — Dark Command Center ──────────────────────────────────────

class AdminColors {
  static const background = Color(0xFF0F1117);
  static const surface = Color(0xFF1A1D27);
  static const surfaceElevated = Color(0xFF222638);
  static const border = Color(0xFF2D3148);

  static const primary = Color(0xFFF5A800);
  static const primaryGlow = Color(0x33F5A800);
  static const secondary = Color(0xFF43A047);
  static const secondaryGlow = Color(0x2243A047);

  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFFC107);
  static const error = Color(0xFFEF5350);
  static const info = Color(0xFF42A5F5);

  static const textPrimary = Color(0xFFF0F0F0);
  static const textSecondary = Color(0xFF9E9E9E);
  static const textMuted = Color(0xFF616161);
}

// ─── Theater Manager Palette — Warm Operational ───────────────────────────────

class TMColors {
  static const background = Color(0xFF1A1208);
  static const surface = Color(0xFF261B0C);
  static const surfaceElevated = Color(0xFF332410);
  static const border = Color(0xFF4A3520);

  static const primary = Color(0xFFF5A800);
  static const primaryGlow = Color(0x40F5A800);
  static const secondary = Color(0xFF8D6E63);
  static const accent = Color(0xFFFF8F00);

  static const success = Color(0xFF66BB6A);
  static const warning = Color(0xFFFFCA28);
  static const error = Color(0xFFEF5350);

  static const textPrimary = Color(0xFFF5E6D0);
  static const textSecondary = Color(0xFFBCAAA4);
  static const textMuted = Color(0xFF795548);
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
        vsync: this, duration: const Duration(milliseconds: 1200));
    _countAnim =
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutExpo);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.bgColor,
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        border: Border.all(color: widget.accentColor.withOpacity(0.2)),
        boxShadow: StaffShadow.adminCard(widget.accentColor.withOpacity(0.12)),
      ),
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
          const SizedBox(height: 12),
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
      backgroundColor: AdminColors.surface,
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

class AdminDrawer extends StatelessWidget {
  final String currentRoute;
  final Function(String route) onNavigateTo;
  final VoidCallback? onSignOut;

  const AdminDrawer({
    super.key,
    required this.currentRoute,
    required this.onNavigateTo,
    this.onSignOut,
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

  @override
  Widget build(BuildContext context) {
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
                      Navigator.pop(context);
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
              onTap: onSignOut,
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
            borderRadius: BorderRadius.circular(ShowSnapRadius.sm)),
      ),
    );
  }
}

// ─── TM Drawer ────────────────────────────────────────────────────────────────

class TMDrawer extends StatelessWidget {
  final String currentRoute;
  final String theaterName;
  final Function(String route) onNavigateTo;
  final VoidCallback? onSignOut;

  const TMDrawer({
    super.key,
    required this.currentRoute,
    required this.onNavigateTo,
    this.theaterName = 'My Theater',
    this.onSignOut,
  });

  static const _items = [
    _NavItem(Icons.dashboard_rounded, 'Dashboard', '/tm'),
    _NavItem(Icons.theaters_rounded, 'Screens', '/tm/screens'),
    _NavItem(Icons.movie_rounded, 'Movies', '/tm/movies'),
    _NavItem(Icons.schedule_rounded, 'Shows', '/tm/shows'),
    _NavItem(Icons.qr_code_scanner_rounded, 'Ticket Scanner', '/tm/scanner'),
    _NavItem(Icons.bar_chart_rounded, 'Reports', '/tm/reports'),
  ];

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: TMColors.surface,
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
                      Navigator.pop(context);
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
              onTap: onSignOut,
            ),
          ],
        ),
      ),
    );
  }
}
