import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/coupon_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/database_service.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final _couponsProvider =
    FutureProvider<List<CouponModel>>((ref) =>
        ref.watch(databaseServiceProvider).getAllCoupons());

final _referralCountProvider =
    FutureProvider<int>((ref) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return 0;
  return ref.watch(databaseServiceProvider).getReferralCount(uid);
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class UserOffersScreen extends ConsumerWidget {
  const UserOffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserModelProvider).valueOrNull;
    final uid = user?.uid ?? '';
    final referralCode =
        uid.isNotEmpty ? uid.substring(0, 5).toUpperCase() + '5OFF' : '';
    final rewards = user?.rewards.length ?? 0;

    return Scaffold(
      backgroundColor: ShowSnapColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Offers & Rewards',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_couponsProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Rewards card
            _RewardsCard(rewards: rewards)
                .animate()
                .fadeIn(duration: ShowSnapDuration.normal)
                .slideY(begin: 0.05, end: 0),

            const SizedBox(height: 16),

            // Referral card
            _ReferralCard(code: referralCode)
                .animate()
                .fadeIn(
                    duration: ShowSnapDuration.normal,
                    delay: const Duration(milliseconds: 100))
                .slideY(
                    begin: 0.05,
                    end: 0,
                    delay: const Duration(milliseconds: 100)),

            const SizedBox(height: 20),

            // Coupons section
            const Text('Available Coupons',
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 12),
            _CouponsList(),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

// ─── Rewards Card ─────────────────────────────────────────────────────────────

class _RewardsCard extends StatelessWidget {
  final int rewards;
  const _RewardsCard({required this.rewards});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: ShowSnapTheme.appBarGradient,
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        boxShadow: ShowSnapShadow.elevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.stars_rounded, color: Colors.black87),
              SizedBox(width: 8),
              Text('ShowSnap Rewards',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '$rewards',
            style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: Colors.black87),
          ),
          const Text('Points',
              style: TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 14, color: Colors.black54),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${rewards ~/ 100} ₹ cashback available (100 pts = ₹1)',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Referral Card ────────────────────────────────────────────────────────────

class _ReferralCard extends ConsumerWidget {
  final String code;
  const _ReferralCard({required this.code});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(_referralCountProvider);
    final referralCount = countAsync.valueOrNull ?? 0;
    final goal = 5;
    final progress = (referralCount / goal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ShowSnapColors.surface,
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        boxShadow: ShowSnapShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.group_add_rounded, color: ShowSnapColors.primary),
              SizedBox(width: 8),
              Text('Refer & Earn',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Invite friends — get 200 pts each',
              style: TextStyle(
                  color: ShowSnapColors.grey600, fontSize: 12)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DottedBorder(
                  color: ShowSnapColors.primary,
                  strokeWidth: 2,
                  dashPattern: const [6, 3],
                  borderType: BorderType.RRect,
                  radius: const Radius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Text(
                      code.isEmpty ? '------' : code,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        letterSpacing: 4,
                        color: ShowSnapColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.copy_rounded,
                    color: ShowSnapColors.primary),
                onPressed: code.isEmpty
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Code copied!')),
                        );
                      },
              ),
              IconButton(
                icon: const Icon(Icons.share_rounded,
                    color: ShowSnapColors.secondary),
                onPressed: code.isEmpty
                    ? null
                    : () => Share.share(
                          'Use my ShowSnap referral code $code to get discounts on your first booking!',
                          subject: 'ShowSnap Referral Code',
                        ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$referralCount / $goal friends invited',
                style: const TextStyle(
                    fontSize: 12, color: ShowSnapColors.grey600),
              ),
              Text(
                referralCount >= goal
                    ? '🎉 Bonus earned!'
                    : '${goal - referralCount} more for bonus',
                style: const TextStyle(
                    fontSize: 11, color: ShowSnapColors.secondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: ShowSnapColors.grey300,
              valueColor: const AlwaysStoppedAnimation<Color>(
                  ShowSnapColors.secondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Coupons List ─────────────────────────────────────────────────────────────

class _CouponsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couponsAsync = ref.watch(_couponsProvider);
    return couponsAsync.when(
      loading: () => const Center(
          child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator())),
      error: (e, _) =>
          Center(child: Text('Error: $e')),
      data: (coupons) {
        final active = coupons
            .where((c) => c.isActive)
            .toList();
        if (active.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No coupons available right now',
                  style: TextStyle(color: ShowSnapColors.grey600)),
            ),
          );
        }
        return Column(
          children: active.asMap().entries.map((entry) {
            return _CouponCard(coupon: entry.value)
                .animate()
                .fadeIn(
                    duration: ShowSnapDuration.normal,
                    delay: Duration(milliseconds: 80 * entry.key))
                .slideX(
                    begin: 0.04,
                    end: 0,
                    delay:
                        Duration(milliseconds: 80 * entry.key));
          }).toList(),
        );
      },
    );
  }
}

class _CouponCard extends StatelessWidget {
  final CouponModel coupon;
  const _CouponCard({required this.coupon});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: DottedBorder(
        color: ShowSnapColors.primary,
        strokeWidth: 1.5,
        dashPattern: const [8, 4],
        borderType: BorderType.RRect,
        radius: const Radius.circular(ShowSnapRadius.md),
        child: Container(
          decoration: BoxDecoration(
            color: ShowSnapColors.surface,
            borderRadius: BorderRadius.circular(ShowSnapRadius.md),
          ),
          child: Row(
            children: [
              // Left accent
              Container(
                width: 6,
                height: 90,
                decoration: BoxDecoration(
                  color: ShowSnapColors.primary,
                  borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(ShowSnapRadius.md)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: ShowSnapColors.primaryLighter,
                                borderRadius: BorderRadius.circular(4)),
                            child: Text(coupon.code,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: Colors.black87,
                                    letterSpacing: 2)),
                          ),
                          const Spacer(),
                          _DiscountBadge(coupon: coupon),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        coupon.minOrderValue > 0
                            ? 'Min order ₹${coupon.minOrderValue}${coupon.eligibleCategories.isNotEmpty ? ' · ${coupon.eligibleCategories.join(', ')}' : ''}'
                            : 'Valid on all bookings',
                        style: const TextStyle(
                            fontSize: 12,
                            color: ShowSnapColors.grey600),
                      ),
                      const SizedBox(height: 6),
                      if (coupon.expiryTs > 0)
                        Text(
                          'Expires ${_expLabel(coupon.expiryTs)}',
                          style: const TextStyle(
                              fontSize: 10,
                              color: ShowSnapColors.grey600),
                        ),
                    ],
                  ),
                ),
              ),
              // Copy button
              IconButton(
                icon: const Icon(Icons.copy_rounded,
                    color: ShowSnapColors.primary, size: 20),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: coupon.code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            '${coupon.code} copied to clipboard!')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _expLabel(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _DiscountBadge extends StatelessWidget {
  final CouponModel coupon;
  const _DiscountBadge({required this.coupon});

  @override
  Widget build(BuildContext context) {
    final label = coupon.discountType == DiscountType.percentage
        ? '${coupon.discountValue.toInt()}% OFF'
        : '₹${coupon.discountValue.toInt()} OFF';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ShowSnapColors.primary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: Colors.black87)),
    );
  }
}
