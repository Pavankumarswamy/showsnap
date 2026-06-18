import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/coupon_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/database_service.dart';
import 'em_dashboard_screen.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/showsnap_toast.dart';

final _emCouponsProvider = StreamProvider<List<CouponModel>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value([]);
  return ref.watch(databaseServiceProvider).streamCouponsForManager(uid);
});

class EmCouponsScreen extends ConsumerStatefulWidget {
  const EmCouponsScreen({super.key});

  @override
  ConsumerState<EmCouponsScreen> createState() => _EmCouponsScreenState();
}

class _EmCouponsScreenState extends ConsumerState<EmCouponsScreen> {
  void _showAddCouponDialog() {
    showDialog(
      context: context,
      builder: (context) => const _AddCouponDialog(),
    );
  }

  Future<void> _toggleCouponStatus(CouponModel coupon, bool isActive) async {
    try {
      final updated = CouponModel(
        code: coupon.code,
        discountType: coupon.discountType,
        discountValue: coupon.discountValue,
        maxUses: coupon.maxUses,
        currentUses: coupon.currentUses,
        expiryTs: coupon.expiryTs,
        minOrderValue: coupon.minOrderValue,
        eligibleCategories: coupon.eligibleCategories,
        isActive: isActive,
        managerId: coupon.managerId,
      );
      await ref.read(databaseServiceProvider).saveCoupon(updated);
      if (mounted) {
        ShowSnapToast.success(context, 'Coupon status updated');
      }
    } catch (e) {
      if (mounted) {
        ShowSnapToast.error(context, 'Failed to update coupon: $e');
      }
    }
  }

  Future<void> _deleteCoupon(String code) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Coupon'),
        content: Text('Are you sure you want to delete the coupon $code?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: EMColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await ref.read(databaseServiceProvider).deleteCoupon(code);
        if (mounted) {
          ShowSnapToast.success(context, 'Coupon deleted');
        }
      } catch (e) {
        if (mounted) {
          ShowSnapToast.error(context, 'Failed to delete coupon: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncCoupons = ref.watch(_emCouponsProvider);

    return Scaffold(
      backgroundColor: EMColors.background,
      appBar: AppBar(
        title: const Text('Promo Codes', style: TextStyle(color: EMColors.textPrimary)),
        backgroundColor: EMColors.surface,
        iconTheme: const IconThemeData(color: EMColors.textPrimary),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCouponDialog,
        backgroundColor: EMColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Create Promo', style: TextStyle(fontWeight: FontWeight.bold)),
      ).animate().fadeIn(delay: 500.ms).scale(),
      body: asyncCoupons.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: EMColors.error))),
        data: (coupons) {
          if (coupons.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_offer_outlined, size: 64, color: EMColors.border),
                  const SizedBox(height: 16),
                  const Text('No promo codes yet.', style: TextStyle(color: EMColors.textSecondary)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _showAddCouponDialog,
                    child: const Text('Create your first promo'),
                  ),
                ],
              ),
            ).animate().fadeIn();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: coupons.length,
            itemBuilder: (context, index) {
              final coupon = coupons[index];
              final isExpired = coupon.isExpired;
              final isExhausted = coupon.isExhausted;
              final isValid = coupon.isValid;

              return Card(
                color: EMColors.surfaceElevated,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: EMColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: EMColors.primary),
                            ),
                            child: Text(
                              coupon.code,
                              style: const TextStyle(
                                color: EMColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Switch(
                                value: coupon.isActive,
                                activeColor: EMColors.primary,
                                onChanged: (val) => _toggleCouponStatus(coupon, val),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: EMColors.error),
                                onPressed: () => _deleteCoupon(coupon.code),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _StatItem(
                            label: 'Discount',
                            value: coupon.discountType == DiscountType.percentage
                                ? '${coupon.discountValue}% OFF'
                                : '₹${coupon.discountValue} OFF',
                          ),
                          _StatItem(
                            label: 'Usage',
                            value: '${coupon.currentUses} / ${coupon.maxUses}',
                          ),
                          _StatItem(
                            label: 'Min Order',
                            value: '₹${coupon.minOrderValue}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            coupon.expiryTs > 0
                                ? 'Expires: ${DateFormat('d MMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(coupon.expiryTs))}'
                                : 'No Expiry',
                            style: const TextStyle(color: EMColors.textSecondary, fontSize: 12),
                          ),
                          if (!isValid)
                            Text(
                              isExpired ? 'EXPIRED' : (isExhausted ? 'EXHAUSTED' : 'INACTIVE'),
                              style: const TextStyle(
                                color: EMColors.error,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: Duration(milliseconds: 100 * index)).slideY(begin: 0.1, end: 0);
            },
          );
        },
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: EMColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: EMColors.textPrimary, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _AddCouponDialog extends ConsumerStatefulWidget {
  const _AddCouponDialog();

  @override
  ConsumerState<_AddCouponDialog> createState() => _AddCouponDialogState();
}

class _AddCouponDialogState extends ConsumerState<_AddCouponDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _discountValCtrl = TextEditingController();
  final _minOrderCtrl = TextEditingController();
  final _maxUsesCtrl = TextEditingController(text: '100');

  DiscountType _type = DiscountType.percentage;
  DateTime? _expiryDate;
  bool _saving = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _discountValCtrl.dispose();
    _minOrderCtrl.dispose();
    _maxUsesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _expiryDate = date);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
      
      final coupon = CouponModel(
        code: _codeCtrl.text.trim().toUpperCase(),
        discountType: _type,
        discountValue: double.tryParse(_discountValCtrl.text) ?? 0,
        maxUses: int.tryParse(_maxUsesCtrl.text) ?? 100,
        currentUses: 0,
        expiryTs: _expiryDate?.millisecondsSinceEpoch ?? 0,
        minOrderValue: int.tryParse(_minOrderCtrl.text) ?? 0,
        eligibleCategories: const [],
        isActive: true,
        managerId: uid,
      );

      await ref.read(databaseServiceProvider).saveCoupon(coupon);
      if (mounted) {
        Navigator.pop(context);
        ShowSnapToast.success(context, 'Promo code created successfully!');
      }
    } catch (e) {
      if (mounted) {
        ShowSnapToast.error(context, 'Failed to create promo code: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: EMColors.surface,
      title: const Text('Create Promo Code', style: TextStyle(color: EMColors.textPrimary)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Code (e.g. SUMMER20)',
                  prefixIcon: Icon(Icons.local_offer_outlined),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<DiscountType>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Discount Type',
                  prefixIcon: Icon(Icons.percent),
                ),
                items: DiscountType.values.map((t) => DropdownMenuItem(
                  value: t,
                  child: Text(t == DiscountType.percentage ? 'Percentage (%)' : 'Flat Amount (₹)'),
                )).toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _discountValCtrl,
                decoration: InputDecoration(
                  labelText: _type == DiscountType.percentage ? 'Discount Percentage (%)' : 'Flat Discount (₹)',
                  prefixIcon: const Icon(Icons.money),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _minOrderCtrl,
                decoration: const InputDecoration(
                  labelText: 'Min Order Value (₹)',
                  prefixIcon: Icon(Icons.shopping_cart_outlined),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _maxUsesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Max Uses',
                  prefixIcon: Icon(Icons.group_outlined),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Expiry Date', style: TextStyle(fontSize: 14)),
                subtitle: Text(
                  _expiryDate != null ? DateFormat('d MMM yyyy').format(_expiryDate!) : 'Never expires',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: TextButton(
                  onPressed: _pickDate,
                  child: const Text('SELECT'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('CREATE'),
        ),
      ],
    );
  }
}
