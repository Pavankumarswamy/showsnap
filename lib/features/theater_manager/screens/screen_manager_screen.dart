import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../../core/config/router.dart';
import '../../../core/config/staff_theme.dart';
import '../../../core/config/theme.dart';
import '../../../core/models/screen_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/database_service.dart';
import '../../../core/widgets/showsnap_toast.dart';

final _tmScreensProvider = FutureProvider<List<ScreenModel>>((ref) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return [];
  final theaters = await ref.watch(databaseServiceProvider).getAllTheaters();
  final theater = theaters
      .cast<dynamic>()
      .firstWhere((t) => t.managerId == uid, orElse: () => null);
  if (theater == null) return [];
  return ref
      .watch(databaseServiceProvider)
      .getScreensForTheater(theater.theaterId);
});

class ScreenManagerScreen extends ConsumerWidget {
  const ScreenManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screensAsync = ref.watch(_tmScreensProvider);

    return Scaffold(
      backgroundColor: TMColors.background,
      drawer: TMDrawer(
        currentRoute: AppRoutes.screenManager,
        onNavigateTo: (route) => context.push(route),
        theaterName: 'My Theater',
        onSignOut: () {},
      ),
      appBar: AppBar(
        backgroundColor: TMColors.surface,
        foregroundColor: TMColors.textPrimary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: TMColors.border),
        ),
        title: const Text(
          'Manage Screens',
          style: TextStyle(
              color: TMColors.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddScreenDialog(context, ref),
        label:
            const Text('Add Screen', style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add),
        backgroundColor: TMColors.primary,
        foregroundColor: Colors.black,
      ).animate().scale(
            delay: 300.ms,
            duration: 400.ms,
            curve: Curves.elasticOut,
          ),
      body: screensAsync.when(
        loading: () => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 4,
          itemBuilder: (_, __) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: StaffShimmerCard(
              height: 160,
              baseColor: TMColors.surface,
              highlightColor: TMColors.surfaceElevated,
            ),
          ),
        ),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: AdminColors.error))),
        data: (screens) => screens.isEmpty
            ? StaffEmptyState(
                icon: Icons.theaters_outlined,
                message: 'No screens yet.\nAdd your first screen to get started.',
                ctaLabel: 'Add Screen',
                onCta: () => _showAddScreenDialog(context, ref),
              )
            : RefreshIndicator(
                color: TMColors.primary,
                backgroundColor: TMColors.surface,
                onRefresh: () => ref.refresh(_tmScreensProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: screens.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _ScreenCard(screen: screens[i])
                      .animate()
                      .fadeIn(duration: 400.ms, delay: (i * 70).ms)
                      .slideY(begin: 0.08, end: 0),
                ),
              ),
      ),
    );
  }

  void _showAddScreenDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final seatsCtrl = TextEditingController();
    String technology = '2D';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: TMColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ShowSnapRadius.md),
            side: const BorderSide(color: TMColors.border),
          ),
          title: const Text(
            'Add Screen',
            style: TextStyle(
                color: TMColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _tmField(nameCtrl, 'Screen Name'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: technology,
                dropdownColor: TMColors.surfaceElevated,
                style: const TextStyle(color: TMColors.textPrimary),
                decoration: _tmInputDecoration('Technology'),
                items: ['2D', '3D', 'IMAX', '4DX']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setS(() => technology = v!),
              ),
              const SizedBox(height: 12),
              _tmField(seatsCtrl, 'Total Seats',
                  type: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: TMColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: TMColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ShowSnapRadius.md)),
              ),
              onPressed: () async {
                if (nameCtrl.text.isEmpty) return;
                final uid =
                    ref.read(authStateProvider).valueOrNull?.uid;
                if (uid == null) return;
                final db = ref.read(databaseServiceProvider);
                final theaters = await db.getAllTheaters();
                final theater = theaters.cast<dynamic>().firstWhere(
                    (t) => t.managerId == uid,
                    orElse: () => null);
                if (theater == null) return;

                await db.createScreen(ScreenModel(
                  screenId: '',
                  theaterId: theater.theaterId,
                  name: nameCtrl.text.trim(),
                  technology: technology,
                  totalSeats: int.tryParse(seatsCtrl.text) ?? 0,
                ));
                ref.invalidate(_tmScreensProvider);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ShowSnapToast.success(context, 'Screen created');
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

InputDecoration _tmInputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: TMColors.textSecondary),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ShowSnapRadius.md),
      borderSide: const BorderSide(color: TMColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ShowSnapRadius.md),
      borderSide: const BorderSide(color: TMColors.primary),
    ),
    filled: true,
    fillColor: TMColors.surfaceElevated,
  );
}

Widget _tmField(TextEditingController ctrl, String label,
    {TextInputType type = TextInputType.text}) {
  return TextField(
    controller: ctrl,
    keyboardType: type,
    style: const TextStyle(color: TMColors.textPrimary),
    decoration: _tmInputDecoration(label),
  );
}

class _ScreenCard extends StatelessWidget {
  final ScreenModel screen;
  const _ScreenCard({required this.screen});

  @override
  Widget build(BuildContext context) {
    final layoutPct = screen.totalSeats > 0
        ? (screen.seatLayout.length / screen.totalSeats).clamp(0.0, 1.0)
        : 0.0;
    final layoutColor = layoutPct >= 0.9
        ? TMColors.primary
        : layoutPct >= 0.5
            ? const Color(0xFFFF8F00)
            : const Color(0xFFEF5350);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TMColors.surface,
        borderRadius: BorderRadius.circular(ShowSnapRadius.md),
        border: Border.all(color: TMColors.border),
        boxShadow: StaffShadow.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: TMColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(ShowSnapRadius.sm),
                ),
                child: const Icon(Icons.theaters_outlined,
                    color: TMColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  screen.name,
                  style: const TextStyle(
                      color: TMColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
              if (screen.isUnderMaintenance)
                StaffBadge(
                    label: 'Maintenance', color: const Color(0xFFEF5350)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _InfoChip(screen.technology, Icons.hd_outlined),
              const SizedBox(width: 8),
              _InfoChip('${screen.totalSeats} seats', Icons.event_seat_outlined),
            ],
          ),
          const SizedBox(height: 14),
          // Layout completion indicator
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Seat Layout',
                          style: TextStyle(
                              color: TMColors.textSecondary, fontSize: 12),
                        ),
                        Text(
                          '${screen.seatLayout.length}/${screen.totalSeats} configured',
                          style: TextStyle(
                              color: layoutColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearPercentIndicator(
                      percent: layoutPct,
                      lineHeight: 6,
                      backgroundColor: TMColors.border,
                      progressColor: layoutColor,
                      barRadius: const Radius.circular(3),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.grid_on_outlined,
                      size: 16, color: TMColors.textSecondary),
                  label: const Text('Edit Layout',
                      style: TextStyle(color: TMColors.textSecondary)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: TMColors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ShowSnapRadius.md)),
                  ),
                  onPressed: () =>
                      context.push('/tm/seat-layout/${screen.screenId}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.schedule_outlined, size: 16),
                  label: const Text('Shows'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TMColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ShowSnapRadius.md)),
                  ),
                  onPressed: () => context.push(AppRoutes.showScheduler),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _InfoChip(this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: TMColors.surfaceElevated,
        borderRadius: BorderRadius.circular(ShowSnapRadius.pill),
        border: Border.all(color: TMColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: TMColors.textMuted, size: 13),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(color: TMColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}
