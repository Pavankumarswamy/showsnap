import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/theater_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/database_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AddTheaterScreen extends ConsumerStatefulWidget {
  /// If non-null, this manager will be pre-selected and the picker is hidden.
  final String? fixedManagerId;
  final String? fixedManagerName;

  const AddTheaterScreen({
    super.key,
    this.fixedManagerId,
    this.fixedManagerName,
  });

  @override
  ConsumerState<AddTheaterScreen> createState() => _AddTheaterScreenState();
}

class _AddTheaterScreenState extends ConsumerState<AddTheaterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();

  UserModel? _selectedManager;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Determine managerId
    String managerId = widget.fixedManagerId ?? _selectedManager?.uid ?? '';

    setState(() => _saving = true);
    try {
      final theater = TheaterModel(
        theaterId: '',
        name: _nameCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        contactPhone: _phoneCtrl.text.trim(),
        lat: double.tryParse(_latCtrl.text.trim()) ?? 0,
        lng: double.tryParse(_lngCtrl.text.trim()) ?? 0,
        managerId: managerId,
        isActive: true,
      );

      final db = ref.read(databaseServiceProvider);
      final theaterId = await db.createTheater(theater);

      // If manager selected, ensure their DB role is theaterManager
      if (managerId.isNotEmpty) {
        await db.updateUser(managerId, {'role': AppConstants.roleTheaterManager});
      }

      if (mounted) {
        context.showSnackbar('Theater "${theater.name}" created!');
        Navigator.of(context).pop(theaterId);
      }
    } catch (e) {
      if (mounted) context.showErrorSnackbar('Failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFixedManager = widget.fixedManagerId != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Theater'),
        toolbarHeight: 70,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(35),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: ShowSnapTheme.appBarGradient),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          children: [
            // ── Theater Info Card ─────────────────────────────────────────
            _SectionHeader('Theater Details')
              .animate()
              .fadeIn(duration: 300.ms, delay: 50.ms),
            const SizedBox(height: 10),
            _Field(
              controller: _nameCtrl,
              label: 'Theater Name *',
              icon: Icons.theaters_outlined,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideY(begin: 0.05, end: 0),
            const SizedBox(height: 12),
            _Field(
              controller: _cityCtrl,
              label: 'City *',
              icon: Icons.location_city_outlined,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ).animate().fadeIn(duration: 300.ms, delay: 150.ms).slideY(begin: 0.05, end: 0),
            const SizedBox(height: 12),
            _Field(
              controller: _addressCtrl,
              label: 'Full Address *',
              icon: Icons.place_outlined,
              maxLines: 2,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ).animate().fadeIn(duration: 300.ms, delay: 200.ms).slideY(begin: 0.05, end: 0),
            const SizedBox(height: 12),
            _Field(
              controller: _phoneCtrl,
              label: 'Contact Phone',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ).animate().fadeIn(duration: 300.ms, delay: 250.ms).slideY(begin: 0.05, end: 0),
            const SizedBox(height: 12),

            // Coordinates row
            Row(
              children: [
                Expanded(
                  child: _Field(
                    controller: _latCtrl,
                    label: 'Latitude',
                    icon: Icons.gps_fixed_outlined,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Field(
                    controller: _lngCtrl,
                    label: 'Longitude',
                    icon: Icons.gps_not_fixed_outlined,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms, delay: 300.ms).slideY(begin: 0.05, end: 0),

            const SizedBox(height: 20),

            // ── Manager Assignment ────────────────────────────────────────
            _SectionHeader('Manager Assignment')
              .animate()
              .fadeIn(duration: 300.ms, delay: 350.ms),
            const SizedBox(height: 10),

            if (isFixedManager) ...[
              // TM creating their own theater — show their own name locked
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ShowSnapColors.primaryLighter,
                  borderRadius: BorderRadius.circular(ShowSnapRadius.md),
                  border: Border.all(color: ShowSnapColors.primary),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_outlined,
                        color: ShowSnapColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.fixedManagerName ?? 'You',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: ShowSnapColors.primary)),
                          const Text('Assigned as manager of this theater',
                              style: TextStyle(
                                  fontSize: 12, color: ShowSnapColors.primary)),
                        ],
                      ),
                    ),
                    const Icon(Icons.lock_outline,
                        size: 16, color: ShowSnapColors.primary),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms, delay: 400.ms).slideY(begin: 0.05, end: 0),
            ] else ...[
              // Admin view — pick from theater manager users
              _ManagerPicker(
                selected: _selectedManager,
                onSelected: (u) => setState(() => _selectedManager = u),
              ).animate().fadeIn(duration: 300.ms, delay: 400.ms).slideY(begin: 0.05, end: 0),
            ],

            const SizedBox(height: 28),

            // ── Save Button ───────────────────────────────────────────────
            SizedBox(
              height: 52,
              child: DecoratedBox(
                decoration: ShowSnapTheme.primaryButtonDecoration,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(ShowSnapRadius.md),
                    ),
                  ),
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.save_outlined, color: Colors.black),
                  label: Text(
                    _saving ? 'Saving…' : 'Create Theater',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black),
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 450.ms).slideY(begin: 0.05, end: 0),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Manager Picker ────────────────────────────────────────────────────────────

class _ManagerPicker extends ConsumerWidget {
  final UserModel? selected;
  final ValueChanged<UserModel?> onSelected;

  const _ManagerPicker({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(_tmUsersProvider);

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error loading users: $e'),
      data: (users) {
        if (users.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ShowSnapColors.grey100,
              borderRadius: BorderRadius.circular(ShowSnapRadius.md),
            ),
            child: const Text(
              'No theater managers found.\nCreate a user first and assign them the Theater Manager role.',
              style: TextStyle(color: ShowSnapColors.grey600, fontSize: 13),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Assign Theater Manager (optional)',
                style: TextStyle(fontSize: 13, color: ShowSnapColors.grey600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<UserModel>(
              value: selected,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.manage_accounts_outlined),
                hintText: 'Select a theater manager',
              ),
              items: [
                const DropdownMenuItem<UserModel>(
                  value: null,
                  child: Text('None (assign later)'),
                ),
                ...users.map((u) => DropdownMenuItem<UserModel>(
                      value: u,
                      child: Text(
                          '${u.displayName.isNotEmpty ? u.displayName : u.email} · ${u.role}'),
                    )),
              ],
              onChanged: onSelected,
            ),
          ],
        );
      },
    );
  }
}

// Provider: all users who are theaterManagers OR regular users eligible to manage
final _tmUsersProvider = FutureProvider<List<UserModel>>((ref) async {
  final all = await ref.watch(databaseServiceProvider).getAllUsers();
  // Show theaterManagers + users (admin can promote them)
  return all
      .where((u) =>
          u.role == AppConstants.roleTheaterManager ||
          u.role == AppConstants.roleUser)
      .toList();
});

// ── Reusable Field ────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      validator: validator,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ],
    );
  }
}
