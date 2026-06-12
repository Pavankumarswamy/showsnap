import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/coupon_model.dart';
import '../../../core/models/offer_model.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/extensions.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offers & Coupons'),
        toolbarHeight: 70,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(35),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        flexibleSpace: Container(
          decoration:
              BoxDecoration(gradient: ShowSnapTheme.appBarGradient),
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
          indicatorColor: Colors.black,
          tabs: const [
            Tab(text: 'Milestone Offers'),
            Tab(text: 'Coupon Codes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _MilestoneOffersTab(),
          _CouponCodesTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabs.index == 0) {
            _showAddOfferDialog(context);
          } else {
            _showAddCouponDialog(context);
          }
        },
        label: Text(_tabs.index == 0 ? 'Add Offer' : 'Add Coupon'),
        icon: const Icon(Icons.add),
        backgroundColor: ShowSnapColors.primary,
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
          title: const Text('New Milestone Offer'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<MilestoneType>(
                  value: milestoneType,
                  decoration:
                      const InputDecoration(labelText: 'Milestone Type'),
                  items: MilestoneType.values
                      .map((t) => DropdownMenuItem(
                          value: t, child: Text(t.label)))
                      .toList(),
                  onChanged: (v) => setS(() => milestoneType = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: thresholdCtrl,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Threshold Count'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<RewardType>(
                  value: rewardType,
                  decoration:
                      const InputDecoration(labelText: 'Reward Type'),
                  items: RewardType.values
                      .map((t) => DropdownMenuItem(
                          value: t, child: Text(t.label)))
                      .toList(),
                  onChanged: (v) => setS(() => rewardType = v!),
                ),
                if (rewardType != RewardType.freeTicket) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: valueCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Value (% or ₹)'),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: validityCtrl,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Validity (days)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final db = ref.read(databaseServiceProvider);
                final offerId =
                    'offer_${DateTime.now().millisecondsSinceEpoch}';
                await db.saveOffer(OfferModel(
                  offerId: offerId,
                  milestoneType: milestoneType,
                  threshold:
                      int.tryParse(thresholdCtrl.text) ?? 1,
                  rewardType: rewardType,
                  rewardValue:
                      double.tryParse(valueCtrl.text) ?? 0,
                  validityDays:
                      int.tryParse(validityCtrl.text) ?? 30,
                ));
                ref.invalidate(_offersProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
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
          title: const Text('New Coupon Code'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration:
                      const InputDecoration(labelText: 'Coupon Code'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<DiscountType>(
                  value: discountType,
                  decoration:
                      const InputDecoration(labelText: 'Discount Type'),
                  items: DiscountType.values
                      .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.name.capitalize)))
                      .toList(),
                  onChanged: (v) => setS(() => discountType = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: valueCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: discountType == DiscountType.percentage
                          ? 'Discount %'
                          : 'Flat Amount (₹)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: maxUsesCtrl,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Max Uses'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: minOrderCtrl,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Min Order Value (₹)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
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
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MilestoneOffersTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(_offersProvider);
    return offersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (offers) => offers.isEmpty
          ? const Center(child: Text('No milestone offers yet'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 80),
              itemCount: offers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final o = offers[i];
                return Card(
                  child: ListTile(
                    title: Text(
                        'Every ${o.threshold} ${o.milestoneType.label}'),
                    subtitle: Text(
                        'Reward: ${o.rewardType.label}${o.rewardValue > 0 ? ' (${o.rewardValue})' : ''} — valid ${o.validityDays} days'),
                    trailing: Switch(
                      value: o.isActive,
                      activeColor: ShowSnapColors.primary,
                      onChanged: (_) {},
                    ),
                  ),
                ).animate()
                 .fadeIn(duration: 350.ms, delay: (i % 6 * 50).ms)
                 .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
              },
            ),
    );
  }
}

class _CouponCodesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couponsAsync = ref.watch(_couponsProvider);
    return couponsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (coupons) => coupons.isEmpty
          ? const Center(child: Text('No coupons yet'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 80),
              itemCount: coupons.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final c = coupons[i];
                return Card(
                  child: ListTile(
                    title: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: ShowSnapColors.primaryLighter,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(c.code,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                        ),
                        const SizedBox(width: 8),
                        if (!c.isValid)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: ShowSnapColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: ShowSnapColors.error),
                            ),
                            child: const Text('EXPIRED',
                                style: TextStyle(
                                    color: ShowSnapColors.error,
                                    fontSize: 10)),
                          ),
                      ],
                    ),
                    subtitle: Text(
                        '${c.discountType == DiscountType.percentage ? '${c.discountValue.toInt()}% off' : '₹${c.discountValue.toInt()} off'} • Used: ${c.currentUses}/${c.maxUses}'),
                    trailing: Switch(
                      value: c.isActive,
                      activeColor: ShowSnapColors.primary,
                      onChanged: (_) {},
                    ),
                  ),
                ).animate()
                 .fadeIn(duration: 350.ms, delay: (i % 6 * 50).ms)
                 .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
              },
            ),
    );
  }
}
