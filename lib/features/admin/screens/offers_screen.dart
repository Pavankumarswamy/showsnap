import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/router.dart';
import '../../../core/config/staff_theme.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/coupon_model.dart';
import '../../../core/models/offer_model.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/showsnap_toast.dart';

final _couponsProvider = FutureProvider<List<CouponModel>>((ref) {
  return ref.watch(databaseServiceProvider).getAllCoupons();
});

final _offersProvider = FutureProvider<List<OfferModel>>((ref) {
  return ref.watch(databaseServiceProvider).getAllOffers();
});

class OffersScreen extends ConsumerStatefulWidget {
  const OffersScreen({super.key});

  @override
  ConsumerState<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends ConsumerState<OffersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PushDrawerLayout(
      backgroundColor: AdminColors.background,
      drawer: AdminDrawer(
        currentRoute: AppRoutes.adminOffers,
        onNavigateTo: (route) => context.push(route),
        onSignOut: () {},
      ),
      appBar: AppBar(
        backgroundColor: AdminColors.surface,
        foregroundColor: AdminColors.textPrimary,
        elevation: 0,
        title: const Text(
          'Offers & Coupons',
          style: TextStyle(
              color: AdminColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AdminColors.primary,
          unselectedLabelColor: AdminColors.textSecondary,
          indicatorColor: AdminColors.primary,
          dividerColor: AdminColors.border,
          tabs: const [
            Tab(text: 'Milestones'),
            Tab(text: 'Coupons'),
          ],
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabs,
        builder: (_, __) => FloatingActionButton.extended(
          onPressed: () {
            if (_tabs.index == 0) {
              _showAddOfferDialog(context);
            } else {
              _showAddCouponDialog(context);
            }
          },
          label: Text(
            _tabs.index == 0 ? 'New Milestone' : 'New Coupon',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          icon: const Icon(Icons.add),
          backgroundColor: AdminColors.primary,
          foregroundColor: Colors.black,
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _MilestoneOffersTab(),
          _CouponCodesTab(),
        ],
      ),
    );
  }

  void _showAddOfferDialog(BuildContext context) {
    MilestoneType milestoneType = MilestoneType.uniqueMovies;
    RewardType rewardType = RewardType.freeTicket;
    final thresholdCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final validityCtrl = TextEditingController(text: '30');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AdminColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ShowSnapRadius.md),
            side: const BorderSide(color: AdminColors.border),
          ),
          title: const Text('New Milestone Offer',
              style: TextStyle(
                  color: AdminColors.textPrimary,
                  fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _darkDropdown<MilestoneType>(
                  label: 'Milestone Type',
                  value: milestoneType,
                  items: MilestoneType.values,
                  labelOf: (t) => t.label,
                  onChanged: (v) => setS(() => milestoneType = v!),
                ),
                const SizedBox(height: 12),
                _darkTextField(
                  controller: thresholdCtrl,
                  label: 'Threshold Count',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                _darkDropdown<RewardType>(
                  label: 'Reward Type',
                  value: rewardType,
                  items: RewardType.values,
                  labelOf: (t) => t.label,
                  onChanged: (v) => setS(() => rewardType = v!),
                ),
                if (rewardType != RewardType.freeTicket) ...[
                  const SizedBox(height: 12),
                  _darkTextField(
                    controller: valueCtrl,
                    label: 'Value (% or ₹)',
                    keyboardType: TextInputType.number,
                  ),
                ],
                const SizedBox(height: 12),
                _darkTextField(
                  controller: validityCtrl,
                  label: 'Validity (days)',
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AdminColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(ShowSnapRadius.md)),
              ),
              onPressed: () async {
                final db = ref.read(databaseServiceProvider);
                final offerId =
                    'offer_${DateTime.now().millisecondsSinceEpoch}';
                await db.saveOffer(OfferModel(
                  offerId: offerId,
                  milestoneType: milestoneType,
                  threshold: int.tryParse(thresholdCtrl.text) ?? 1,
                  rewardType: rewardType,
                  rewardValue: double.tryParse(valueCtrl.text) ?? 0,
                  validityDays: int.tryParse(validityCtrl.text) ?? 30,
                ));
                ref.invalidate(_offersProvider);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ShowSnapToast.success(
                      context, 'Milestone offer created');
                }
              },
              child: const Text('Save',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCouponDialog(BuildContext context) {
    final codeCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final maxUsesCtrl = TextEditingController(text: '100');
    final minOrderCtrl = TextEditingController(text: '0');
    DiscountType discountType = DiscountType.percentage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AdminColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ShowSnapRadius.md),
            side: const BorderSide(color: AdminColors.border),
          ),
          title: const Text('New Coupon Code',
              style: TextStyle(
                  color: AdminColors.textPrimary,
                  fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _darkTextField(
                  controller: codeCtrl,
                  label: 'Coupon Code',
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                _darkDropdown<DiscountType>(
                  label: 'Discount Type',
                  value: discountType,
                  items: DiscountType.values,
                  labelOf: (t) => t.name.capitalize,
                  onChanged: (v) => setS(() => discountType = v!),
                ),
                const SizedBox(height: 12),
                _darkTextField(
                  controller: valueCtrl,
                  label: discountType == DiscountType.percentage
                      ? 'Discount %'
                      : 'Flat Amount (₹)',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                _darkTextField(
                  controller: maxUsesCtrl,
                  label: 'Max Uses',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                _darkTextField(
                  controller: minOrderCtrl,
                  label: 'Min Order Value (₹)',
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AdminColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(ShowSnapRadius.md)),
              ),
              onPressed: () async {
                if (codeCtrl.text.isEmpty) return;
                final db = ref.read(databaseServiceProvider);
                await db.saveCoupon(CouponModel(
                  code: codeCtrl.text.trim().toUpperCase(),
                  discountType: discountType,
                  discountValue: double.tryParse(valueCtrl.text) ?? 0,
                  maxUses: int.tryParse(maxUsesCtrl.text) ?? 100,
                  minOrderValue: int.tryParse(minOrderCtrl.text) ?? 0,
                ));
                ref.invalidate(_couponsProvider);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ShowSnapToast.success(context, 'Coupon created');
                }
              },
              child: const Text('Save',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Dark form helpers ────────────────────────────────────────────────────────

Widget _darkTextField({
  required TextEditingController controller,
  required String label,
  TextInputType keyboardType = TextInputType.text,
  TextCapitalization textCapitalization = TextCapitalization.none,
}) {
  return TextField(
    controller: controller,
    keyboardType: keyboardType,
    textCapitalization: textCapitalization,
    style: const TextStyle(color: AdminColors.textPrimary),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AdminColors.textSecondary),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        borderSide: const BorderSide(color: AdminColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        borderSide: const BorderSide(color: AdminColors.primary),
      ),
      filled: true,
      fillColor: AdminColors.surfaceElevated,
    ),
  );
}

Widget _darkDropdown<T>({
  required String label,
  required T value,
  required List<T> items,
  required String Function(T) labelOf,
  required void Function(T?) onChanged,
}) {
  return DropdownButtonFormField<T>(
    value: value,
    dropdownColor: AdminColors.surfaceElevated,
    style: const TextStyle(color: AdminColors.textPrimary),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AdminColors.textSecondary),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        borderSide: const BorderSide(color: AdminColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        borderSide: const BorderSide(color: AdminColors.primary),
      ),
      filled: true,
      fillColor: AdminColors.surfaceElevated,
    ),
    items: items
        .map((t) => DropdownMenuItem(value: t, child: Text(labelOf(t))))
        .toList(),
    onChanged: onChanged,
  );
}

// ─── Milestones Tab ───────────────────────────────────────────────────────────

class _MilestoneOffersTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(_offersProvider);
    return offersAsync.when(
      loading: () => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: StaffShimmerCard(
            height: 80,
            baseColor: AdminColors.surface,
            highlightColor: AdminColors.surfaceElevated,
          ),
        ),
      ),
      error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: AdminColors.error))),
      data: (offers) => offers.isEmpty
          ? StaffEmptyState(
              icon: Icons.local_offer_outlined,
              message: 'No milestone offers yet.\nTap + to create one.',
            )
          : RefreshIndicator(
              color: AdminColors.primary,
              backgroundColor: AdminColors.surface,
              onRefresh: () => ref.refresh(_offersProvider.future),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: offers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final o = offers[i];
                  return _MilestoneCard(offer: o)
                      .animate()
                      .fadeIn(duration: 350.ms, delay: (i % 6 * 50).ms)
                      .slideY(begin: 0.08, end: 0);
                },
              ),
            ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  final OfferModel offer;
  const _MilestoneCard({required this.offer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AdminColors.primaryGlow,
              borderRadius: BorderRadius.circular(ShowSnapRadius.sm),
            ),
            child: const Icon(Icons.emoji_events_rounded,
                color: AdminColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Every ${offer.threshold} ${offer.milestoneType.label}',
                  style: const TextStyle(
                      color: AdminColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                Text(
                  'Reward: ${offer.rewardType.label}${offer.rewardValue > 0 ? ' (${offer.rewardValue.toStringAsFixed(0)})' : ''} · ${offer.validityDays} days',
                  style: const TextStyle(
                      color: AdminColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          StaffBadge(
            label: offer.isActive ? 'Active' : 'Inactive',
            color: offer.isActive
                ? AdminColors.success
                : AdminColors.textMuted,
          ),
        ],
      ),
    );
  }
}

// ─── Coupons Tab ──────────────────────────────────────────────────────────────

class _CouponCodesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couponsAsync = ref.watch(_couponsProvider);
    return couponsAsync.when(
      loading: () => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: StaffShimmerCard(
            height: 80,
            baseColor: AdminColors.surface,
            highlightColor: AdminColors.surfaceElevated,
          ),
        ),
      ),
      error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: AdminColors.error))),
      data: (coupons) => coupons.isEmpty
          ? StaffEmptyState(
              icon: Icons.discount_outlined,
              message: 'No coupon codes yet.\nTap + to create one.',
            )
          : RefreshIndicator(
              color: AdminColors.primary,
              backgroundColor: AdminColors.surface,
              onRefresh: () => ref.refresh(_couponsProvider.future),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: coupons.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final c = coupons[i];
                  return _CouponCard(coupon: c)
                      .animate()
                      .fadeIn(duration: 350.ms, delay: (i % 6 * 50).ms)
                      .slideY(begin: 0.08, end: 0);
                },
              ),
            ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  final CouponModel coupon;
  const _CouponCard({required this.coupon});

  @override
  Widget build(BuildContext context) {
    final isValid = coupon.isValid;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AdminColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(ShowSnapRadius.sm),
              border: Border.all(
                  color: AdminColors.primary.withOpacity(0.3)),
            ),
            child: Text(
              coupon.code,
              style: const TextStyle(
                  color: AdminColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1.5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coupon.discountType == DiscountType.percentage
                      ? '${coupon.discountValue.toInt()}% off'
                      : '₹${coupon.discountValue.toInt()} off',
                  style: const TextStyle(
                      color: AdminColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
                Text(
                  'Used: ${coupon.currentUses}/${coupon.maxUses}',
                  style: const TextStyle(
                      color: AdminColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          StaffBadge(
            label: isValid ? 'Active' : 'Expired',
            color: isValid ? AdminColors.success : AdminColors.error,
          ),
        ],
      ),
    );
  }
}
